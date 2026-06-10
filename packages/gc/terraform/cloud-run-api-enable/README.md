# cloud-run-api-enable (mutating)

[cloud-run-service-basic](../cloud-run-service-basic/) が前提とする3つの API を有効化する **mutating** サンプルです。
`google_project_service` リソースを `for_each` で回し、複数の API を1つの root module でまとめて管理します。
**プロジェクトの状態（有効な API）を変更する**サンプルです。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `cloud-run-api-enable` に読み替えます。
> 例: `mise exec -- terraform -chdir=packages/gc/terraform/cloud-run-api-enable apply`

## このサンプルが行うこと

次の3つの API を有効化（既に有効なら現状維持）します。

| API | 用途 |
| --- | --- |
| `run.googleapis.com` | Cloud Run service の作成 / 実行 |
| `artifactregistry.googleapis.com` | container image を push する Docker repository |
| `cloudbuild.googleapis.com` | `gcloud builds submit` による image の build / push |

- 単一 API を管理する [storage-api-enable](../storage-api-enable/) と同じ `google_project_service` を使い、こちらは `for_each` で3 API を1つの root module にまとめています。
- `disable_on_destroy = false` を明示しているため、`terraform destroy` で**この Terraform リソースは state から削除されますが、API 自体は有効なまま**残ります。これは、cleanup によって同じ API を使う他のワークロードを壊さないための安全策です。

## 前提（このサンプル固有）

- API を管理するための Service Usage API (`serviceusage.googleapis.com`) は**前提**として有効である必要があります（このサンプルでは管理しません）。「API を管理する API」を自分で有効化させると、初学者にとって分かりにくいブートストラップになるため、意図的に対象外にしています。

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `services` | 管理対象の API サービス名の一覧 |
| `service_ids` | API 名 → リソース ID（`{project}/{service}` 形式）の map |
| `disable_on_destroy` | API 名 → destroy 時に無効化するか（いずれも意図的に `false`）の map |

## cleanup

```bash
mise exec -- terraform -chdir=packages/gc/terraform/cloud-run-api-enable destroy
```

`disable_on_destroy = false` のため、`destroy` 後も3つの API は有効なままです。
API が実際に有効かどうかは `gcloud services list --enabled` で確認できます（[gcloud CLI 基本コマンド](../../../../docs/guides/gcloud-cli/README.md) を参照）。
