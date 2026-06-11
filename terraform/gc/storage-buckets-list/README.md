# storage-buckets-list (read-only)

Google Cloud プロジェクト内の Cloud Storage bucket 一覧を読み取る read-only サンプルです。
`data "google_storage_buckets" "current"` を読むだけで、**Google Cloud リソースは作成・変更・削除しません**。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `storage-buckets-list` に読み替えます。
> 例: `mise exec -- terraform -chdir=terraform/gc/storage-buckets-list plan`

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `bucket_count` | プロジェクト内の bucket 数（**0 件も正常**） |
| `buckets` | 各 bucket の `name` / `location` / `storage_class` |

`google_storage_buckets` は list 系 data source で、`buckets` に全 bucket が返ります。
プロジェクトに bucket が1つも無い場合は空リスト（`bucket_count = 0`）になり、**これは正常な学習結果**です。
実際に bucket を1つ作る手順は [storage-bucket-basic](../storage-bucket-basic/) を参照してください。
作成した bucket に object を upload する発展手順は [storage-object-upload](../storage-object-upload/) を参照してください。

## 前提（このサンプル固有）

- bucket 一覧の取得には、対象プロジェクトで Cloud Storage API (`storage.googleapis.com`) が有効である必要があります（[storage-api-enable](../storage-api-enable/) 参照。このサンプルでは有効化しません）。

このサンプルは Google Cloud リソースを作成しないため、`terraform destroy` で削除する対象はありません。
