# Terraform Google Cloud サンプル集

Google Cloud provider の認証と Terraform の基本操作を学ぶための、自己完結したサンプル集です。
各サンプルは `terraform/` 直下の `<operation>/` に**独立した root module** として置かれ、それぞれ単独で `init` / `plan` / `apply` できます（state もサンプルごとに分離されるため、あるサンプルの操作が他へ波及しません）。

## サンプル一覧

| サンプル | 種別 | 説明 |
| --- | --- | --- |
| [project-info](./project-info/) | read-only | `google_project` data source で project `nck-sakurai` の ID / number / 表示名を読む最小サンプル |
| [service-accounts-list](./service-accounts-list/) | read-only | `google_service_accounts` data source で project の service account 一覧を読む |
| [storage-api-enable](./storage-api-enable/) | mutating | `google_project_service` で `storage.googleapis.com` を有効化する（`disable_on_destroy = false`） |
| [storage-buckets-list](./storage-buckets-list/) | read-only | `google_storage_buckets` data source で Cloud Storage bucket 一覧を読む（0 件も正常） |
| [storage-service-account](./storage-service-account/) | read-only | `google_storage_project_service_account` data source で Cloud Storage service agent の identity を読む |
| [storage-bucket-basic](./storage-bucket-basic/) | mutating | `google_storage_bucket` で private bucket を1つ作成し、[`cleanup.md`](./storage-bucket-basic/cleanup.md) の手順で `destroy` まで lifecycle を学ぶ |
| [storage-object-upload](./storage-object-upload/) | mutating | `google_storage_bucket_object` で既存 bucket に local file を1つ upload し、object cleanup まで学ぶ |
| [cloud-run-api-enable](./cloud-run-api-enable/) | mutating | `google_project_service` を `for_each` で回し、Cloud Run 一式の3 API（`run` / `artifactregistry` / `cloudbuild`）を有効化する（`disable_on_destroy = false`） |
| [cloud-run-service-basic](./cloud-run-service-basic/) | mutating | Artifact Registry repository と private な Cloud Run service を作成し、[apps/cloud-run-rest](../apps/cloud-run-rest/) の image を deploy する（image の build / push は `gcloud builds submit`） |
| [vertex-ai-api-enable](./vertex-ai-api-enable/) | mutating | `google_project_service` で `aiplatform.googleapis.com`（Vertex AI / Agent Engine の API）を有効化する（`disable_on_destroy = false`） |
| [adk-agent-engine-basic](./adk-agent-engine-basic/) | mutating | `google_vertex_ai_reasoning_engine` で [apps/adk-helloworld](../apps/adk-helloworld/) を Vertex AI Agent Engine へ inline source 方式で deploy する（source archive の生成は `package-agent-engine.sh`） |

新しいサンプルは `terraform/` 直下にディレクトリを 1 つ足し、この表に 1 行追加します（`<operation>` は `storage-bucket-list` のような kebab-case の「対象 + 操作」）。read-only は名詞 / `*-list` / `*-read`、リソースを作成する mutating はリソース名中心で命名し、本表の「種別」列で区別します。

## 学習順序

read-only の基礎から、低リスクな mutating（リソース作成）へ段階的に進む構成です。

1. [project-info](./project-info/) — provider 設定 / ADC / `google_project` / outputs / `postcondition` を学ぶ。
2. [service-accounts-list](./service-accounts-list/) — list 系 data source（`google_service_accounts`）を学ぶ。
3. [storage-api-enable](./storage-api-enable/) — `google_project_service` で API を有効化する（mutating の入口、`disable_on_destroy = false`）。
4. [storage-buckets-list](./storage-buckets-list/) — `google_storage_buckets` で在庫を読む（空リストも正常）。
5. [storage-service-account](./storage-service-account/) — provider 管理の service agent を data source から取得する。
6. [storage-bucket-basic](./storage-bucket-basic/) — `plan` / `apply` / `state` / `destroy` を private bucket 1つで学ぶ。
7. [storage-object-upload](./storage-object-upload/) — 既存 bucket に local file を object として upload し、object と bucket の cleanup 順序を学ぶ。
8. [cloud-run-api-enable](./cloud-run-api-enable/) — `google_project_service` を `for_each` で複数 API に展開し、Cloud Run 一式の前提 API をまとめて有効化する。
9. [cloud-run-service-basic](./cloud-run-service-basic/) — Artifact Registry + Cloud Run で「Terraform の外で image を push する」2段階 apply と、private service の認証付き動作確認を学ぶ。
10. [vertex-ai-api-enable](./vertex-ai-api-enable/) — `google_project_service` で Vertex AI API を有効化する（Agent Engine の前提）。
11. [adk-agent-engine-basic](./adk-agent-engine-basic/) — `google_vertex_ai_reasoning_engine` で [apps/adk-helloworld](../apps/adk-helloworld/) を Agent Engine へ deploy する。「Terraform の外で source archive を作る」依存と、AdkApp entrypoint・inline source 方式を学ぶ。

## 種別ごとの扱い（read-only / mutating）

- **read-only**: data source を読むだけで、リソースの作成・変更・削除はしません。`destroy` で消す対象もありません。
- **mutating**: プロジェクトの状態（有効な API やリソース）を変更します。**学習後は各サンプルの README に従って `destroy` してください**。
  - [storage-api-enable](./storage-api-enable/) は `disable_on_destroy = false` のため、`destroy` 後も API は有効なまま残ります（他のワークロードを壊さないため）。
  - [storage-bucket-basic](./storage-bucket-basic/) は [`cleanup.md`](./storage-bucket-basic/cleanup.md) の手順で bucket を削除します。`force_destroy = false` のため、bucket 内にオブジェクトが残っていると `destroy` は失敗します。
  - [storage-object-upload](./storage-object-upload/) は既存 bucket に object を作成します。bucket を削除する前に、このサンプルの [`cleanup.md`](./storage-object-upload/cleanup.md) で object を先に削除してください。
  - [cloud-run-api-enable](./cloud-run-api-enable/) は `disable_on_destroy = false` のため、`destroy` 後も3つの API は有効なまま残ります（[cloud-run-service-basic](./cloud-run-service-basic/) の前提）。
  - [cloud-run-service-basic](./cloud-run-service-basic/) は [`cleanup.md`](./cloud-run-service-basic/cleanup.md) の手順で service と repository を削除します。repository の削除は **push 済みの image ごと**消えます。Cloud Build の staging bucket は Terraform 管理外のため残ります（同 cleanup.md 参照）。
  - [vertex-ai-api-enable](./vertex-ai-api-enable/) は `disable_on_destroy = false` のため、`destroy` 後も `aiplatform.googleapis.com` は有効なまま残ります（[adk-agent-engine-basic](./adk-agent-engine-basic/) の前提）。
  - [adk-agent-engine-basic](./adk-agent-engine-basic/) は [`cleanup.md`](./adk-agent-engine-basic/cleanup.md) の手順で Agent Engine を削除します。source archive（`.build/`）は Terraform 管理外のローカル artifact のため、同 cleanup.md で別途片付けます。apply / destroy は managed runtime の build / 解体を伴い時間がかかります。

## 前提

- `mise run bs` が完了していること
- `nck-sakurai` を読める Google Cloud の認証情報があること
- 対象プロジェクトで Cloud Resource Manager API が有効であること（このサンプルでは有効化しません）

認証は Application Default Credentials (ADC) など、Terraform Google provider の標準の仕組みを使います。例:

```bash
gcloud auth application-default login
```

`gcloud` の基本コマンドや active account / project の確認手順は [gcloud CLI 基本コマンド](../../../docs/guides/gcloud-cli/README.md) を参照してください。

シークレット値は repository に保存しないでください。

## 使い方

`<example>` を実際のサンプル名（例: `project-info`）に置き換えて実行します。`tf` ラッパータスクは AWS サンプル専用のため、Google Cloud サンプルは `terraform` を直接呼びます。

```bash
mise exec -- terraform -chdir=packages/gc/terraform/<example> init      # provider plugin を取得し作業ディレクトリを初期化 (最初に一度)
mise exec -- terraform -chdir=packages/gc/terraform/<example> fmt -check # .tf の整形ズレを検出 (書き換えず差分の有無のみ確認)
mise exec -- terraform -chdir=packages/gc/terraform/<example> validate   # 構文・設定の整合性を静的チェック
mise exec -- terraform -chdir=packages/gc/terraform/<example> plan       # 実行計画を表示
mise exec -- terraform -chdir=packages/gc/terraform/<example> apply      # 計画を適用し output を表示
```

## 各サンプルが生成するファイル

- `.terraform.lock.hcl`: provider の選択を固定する lock file。**commit 対象**です。
- `.terraform/`: provider plugin などの local cache。commit しません。
- `terraform.tfstate*`: local state。commit しません。
- `terraform.tfvars` / `*.tfvars`: 変数を渡す local 値。**commit しません**（[storage-bucket-basic](./storage-bucket-basic/) のように変数を取るサンプルで使用）。
- `terraform.tfvars.template`: `.tfvars` の雛形。プレースホルダのみを含み、**commit 対象**です（`cp ...template ...tfvars` して自分の値を設定）。

`.gitignore` はリポジトリ全体で上記 runtime ファイル（`.tfvars` を含む）を（任意のネスト深さで）無視し、`*.template` だけを追跡対象に残すため、`terraform/` 配下にサンプルを増やしても gitignore の追加設定は不要です。
