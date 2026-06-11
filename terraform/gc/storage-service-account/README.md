# storage-service-account (read-only)

プロジェクトの Cloud Storage service account（Google が管理する service agent）の identity を読み取る read-only サンプルです。
`data "google_storage_project_service_account" "current"` を読むだけで、**Google Cloud リソースは作成・変更・削除しません**。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `storage-service-account` に読み替えます。
> 例: `mise exec -- terraform -chdir=terraform/gc/storage-service-account plan`

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `email_address` | Cloud Storage service agent の email アドレス |
| `member` | IAM binding に使える `serviceAccount:{email}` 形式の member 文字列 |

## なぜ data source なのか

Cloud Storage service agent の email は project 番号から「それっぽく」組み立てることもできますが、
**その形式は Google / provider 側の管理対象で変わり得る**ため、手組みの文字列は気付かないうちに誤りになる恐れがあります。
`google_storage_project_service_account` data source から取得すれば、常に正しい identity を参照できます（Pub/Sub 通知や CMEK の権限付与でよく使います）。

## 前提（このサンプル固有）

- この identity の取得には、対象プロジェクトで Cloud Storage API (`storage.googleapis.com`) が有効である必要があります（[storage-api-enable](../storage-api-enable/) 参照。このサンプルでは有効化しません）。

このサンプルは Google Cloud リソースを作成しないため、`terraform destroy` で削除する対象はありません。
