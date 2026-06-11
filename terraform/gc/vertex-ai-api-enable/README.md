# vertex-ai-api-enable (mutating)

Vertex AI API (`aiplatform.googleapis.com`) を有効化する **mutating** サンプルです。
`google_project_service` リソースでプロジェクトの API を1つ管理します。
storage 系・Cloud Run 系で API 有効化を専用サンプル（[storage-api-enable](../storage-api-enable/) /
[cloud-run-api-enable](../cloud-run-api-enable/)）に分離したのと同じ方針で、
[adk-agent-engine-basic](../adk-agent-engine-basic/) の前提 API をここで分離して管理します。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `vertex-ai-api-enable` に読み替えます。
> 例: `mise exec -- terraform -chdir=terraform/gc/vertex-ai-api-enable apply`

## このサンプルが行うこと

- `aiplatform.googleapis.com` を有効化（既に有効なら現状維持）します。これは Vertex AI の API で、
  Agent Engine（Reasoning Engine）リソースもこの API が提供します。
- 他の API は管理しません（`aiplatform.googleapis.com` のみ）。Agent Engine の **inline_source
  （python_spec）方式**ではこの1 API で足り、storage / cloudbuild は不要です
  （それらは GCS package 方式や container image 方式でのみ必要）。
- `disable_on_destroy = false` を明示しているため、`terraform destroy` で**この Terraform リソースは
  state から削除されますが、API 自体は有効なまま**残ります。cleanup によって Vertex AI を使う
  他のワークロードを壊さないための安全策です。

## 前提（このサンプル固有）

- API を管理するための Service Usage API (`serviceusage.googleapis.com`) は**前提**として有効である
  必要があります（このサンプルでは管理しません）。「API を管理する API」を自分で有効化させると、
  初学者にとって分かりにくいブートストラップになるため、意図的に対象外にしています。

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `service` | 管理対象の API サービス名（`aiplatform.googleapis.com`） |
| `service_id` | リソース ID（`{project}/{service}` 形式） |
| `disable_on_destroy` | destroy 時に API を無効化するか（意図的に `false`） |

## cleanup

```bash
mise exec -- terraform -chdir=terraform/gc/vertex-ai-api-enable destroy
```

`disable_on_destroy = false` のため、`destroy` 後も `aiplatform.googleapis.com` は有効なままです。
API が実際に有効かどうかは `gcloud services list --enabled` で確認できます（[gcloud CLI 基本コマンド](../../../../docs/guides/gcloud-cli/README.md) を参照）。
