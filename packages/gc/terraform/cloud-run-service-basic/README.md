# cloud-run-service-basic (mutating)

Artifact Registry の Docker repository と、private な Cloud Run service を作成する **mutating** サンプルです。
deploy するアプリ本体は [packages/gc/apps/cloud-run-rest/](../../apps/cloud-run-rest/) にあり、
**infrastructure は Terraform、container image の build / push は `gcloud builds submit`** という責務分離を学びます。
**実際に課金対象になり得るリソースを作成する**ため、学習後は [`cleanup.md`](./cleanup.md) の手順で `destroy` してください。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `cloud-run-service-basic` に読み替えます。

## 前提（API の有効化）

storage 系で API 有効化を [storage-api-enable](../storage-api-enable/) という専用サンプルに分離したのと同じ方針で、
このサンプルの root module は API を有効化しません。次の3つの API が有効である必要があります。

```bash
gcloud services enable --project nck-sakurai \
  run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
```

## 全体の流れ（2段階 apply）

このサンプルには「repository が image push より先に必要で、image が service の deploy より先に必要」という、
**Terraform の外側を経由する依存関係**があります。そのため1回の `apply` では完結せず、次の順で進めます。

1. image の tag を先に決めて `terraform.tfvars` に URI を設定
2. `-target` で Artifact Registry repository だけを先に `apply`
3. `gcloud builds submit` で同じ tag の image を build して repository に push
4. 全体を `plan` / `apply`

> `-target` は「依存グラフの一部だけを適用する」例外的なフラグで、通常運用では非推奨です
> （state と構成のズレを生みやすいため）。ここでは「Terraform の外で image を push する」という
> 構造上の理由があるため、初回 bootstrap に限って使います。手順4の full `apply` で全体が同期されます。

## 変数の設定（必須）

image URI は build のたびに変わるため、固定値は埋め込まず変数で受け取ります。
`terraform.tfvars` は「操作の流れ」手順1の `echo` でそのまま生成できます（gitignore 対象でコミットされません）。
[`terraform.tfvars.template`](./terraform.tfvars.template) は変数の一覧と書式の参照用です。

`region` などの default を上書きしたい場合のみ、template を copy して手で編集してください。
この場合は手順1の `echo`（ファイルを上書きします）を実行せず、`image` 行を手で設定します。

```bash
cp packages/gc/terraform/cloud-run-service-basic/terraform.tfvars.template \
   packages/gc/terraform/cloud-run-service-basic/terraform.tfvars
# terraform.tfvars を編集し、image（と必要な override）を設定
```

> tag は push 前に決められる（URI は push してもしなくても同じ形）ため、**最初に tag を決めて
> tfvars に設定**してから進めます。プレースホルダのままだと validation が止めてくれます。

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `image` | ○ | （なし） | deploy する image の tag 付き完全 URI（`gcloud builds submit --tag` に渡した値）。validation により tag は小文字のみ・`latest` 不可・この module が作る repository の URI 限定です |
| `region` | | `asia-northeast1` | repository と service を置く region（小文字表記） |
| `repository_id` | | `cloud-run-rest` | Artifact Registry repository の ID |
| `service_name` | | `cloud-run-rest` | Cloud Run service の名前 |

## このサンプルが作るリソース

| リソース | 内容 |
| --- | --- |
| `google_artifact_registry_repository.learning` | Docker format の repository。image の push 先 |
| `google_cloud_run_v2_service.learning` | private な Cloud Run service。`deletion_protection = false`、最大 instance 数 1 |

**private の実現方法**: invoker の IAM binding を一切作らないことで、default の
「project Owner / Editor 以外は呼び出せない」状態を保ちます。`allUsers` への公開（誰でもアクセス可能）はこのサンプルでは扱いません。
ネットワーク的には到達可能（ingress は default のまま）ですが、認証なしのリクエストは IAM により 403 になります。

## 操作の流れ

```bash
D=packages/gc/terraform/cloud-run-service-basic

# 1. tag を決めて image URI を terraform.tfvars に設定
TAG="$(git rev-parse --short HEAD)"
IMAGE="asia-northeast1-docker.pkg.dev/nck-sakurai/cloud-run-rest/cloud-run-rest:${TAG}"
echo "image = \"${IMAGE}\"" > $D/terraform.tfvars

# 2. 初期化と repository の先行作成
mise exec -- terraform -chdir=$D init
mise exec -- terraform -chdir=$D apply -target=google_artifact_registry_repository.learning

# 3. 同じ tag で image を build / push（アプリのディレクトリから実行）
(cd packages/gc/apps/cloud-run-rest && \
  gcloud builds submit --project nck-sakurai --tag "${IMAGE}" .)

# 4. 全体を plan / apply
mise exec -- terraform -chdir=$D plan
mise exec -- terraform -chdir=$D apply
```

手順3の build / push の詳細（アップロード範囲、tag の付け方、staging bucket）は
[アプリ側 README](../../apps/cloud-run-rest/README.md) を参照してください。

## 動作確認（認証付き）

service は private のため、認証なしのリクエストは 403 になります。
ID token を付けると、`run.routes.invoke` 権限を持つユーザー（project Owner / Editor を含む）として 200 が返ります。

```bash
D=packages/gc/terraform/cloud-run-service-basic
SERVICE_URI="$(mise exec -- terraform -chdir=$D output -raw service_uri)"

# 認証なし → 403 Forbidden
curl -i -s "${SERVICE_URI}" | head -1

# ID token 付き → 200 + JSON（revision / service に Cloud Run 上の値が入る）
curl -s -H "Authorization: Bearer $(gcloud auth print-identity-token)" "${SERVICE_URI}"
```

> `gcloud auth print-identity-token` の token は手元の開発者確認用です。
> 本番のサービス間呼び出しでは audience を指定した service account の ID token を使います。

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `service_uri` | Cloud Run service の URL（認証付き確認に使用） |
| `repository_id` | 作成した repository の ID |
| `service_name` | 作成した service の名前 |

## cleanup

学習が終わったら必ずリソースを削除してください（課金とリソース残留を避けるため）。
削除順序の考え方を含む詳細な手順は [`cleanup.md`](./cleanup.md) にまとめています。
