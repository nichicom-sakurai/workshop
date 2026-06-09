# storage-api-enable (mutating)

Cloud Storage API (`storage.googleapis.com`) を有効化する **mutating** サンプルです。
`google_project_service` リソースでプロジェクトの API を1つ管理します。
**プロジェクトの状態（有効な API）を変更する**ため、`apply` / `destroy` を伴う最初の学習サンプルです。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `storage-api-enable` に読み替えます。
> 例: `mise exec -- terraform -chdir=packages/gc/terraform/storage-api-enable apply`

## このサンプルが行うこと

- `storage.googleapis.com` を有効化（既に有効なら現状維持）します。
- 他の API は管理しません（`storage.googleapis.com` のみ）。
- `disable_on_destroy = false` を明示しているため、`terraform destroy` で**この Terraform リソースは state から削除されますが、API 自体は有効なまま**残ります。これは、cleanup によって Cloud Storage を使う他のワークロードを壊さないための安全策です。

## 前提（このサンプル固有）

- API を管理するための Service Usage API (`serviceusage.googleapis.com`) は**前提**として有効である必要があります（このサンプルでは管理しません）。「API を管理する API」を自分で有効化させると、初学者にとって分かりにくいブートストラップになるため、意図的に対象外にしています。

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `service` | 管理対象の API サービス名（`storage.googleapis.com`） |
| `service_id` | リソース ID（`{project}/{service}` 形式） |
| `disable_on_destroy` | destroy 時に API を無効化するか（意図的に `false`） |

## cleanup

```bash
mise exec -- terraform -chdir=packages/gc/terraform/storage-api-enable destroy
```

`disable_on_destroy = false` のため、`destroy` 後も `storage.googleapis.com` は有効なままです。
API が実際に有効かどうかは `gcloud services list --enabled` で確認できます（[gcloud CLI 基本コマンド](../../../../docs/guides/gcloud-cli/README.md) を参照）。
