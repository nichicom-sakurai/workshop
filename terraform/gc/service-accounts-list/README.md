# service-accounts-list (read-only)

Google Cloud プロジェクト内の service account 一覧を読み取る read-only サンプルです。
`data "google_service_accounts" "current"` を読むだけで、**Google Cloud リソースは作成・変更・削除しません**。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `service-accounts-list` に読み替えます。
> 例: `mise exec -- terraform -chdir=packages/gc/terraform/service-accounts-list plan`

## 出力 (outputs)

`plan` / `apply` すると以下が表示されます（定義は [`outputs.tf`](./outputs.tf)）。

| output | 内容 |
| --- | --- |
| `service_account_count` | プロジェクト内の service account 数 |
| `service_accounts` | 各 service account の `account_id` / `email` / `display_name` / `disabled`（非機密の識別情報のみ） |

`google_service_accounts` は list 系 data source で、`accounts` に全 service account が返ります。
1件も無い場合は空リストになり、それも正常な学習結果です。

## 前提（このサンプル固有）

- service account 一覧の取得には、対象プロジェクトで IAM API (`iam.googleapis.com`) が有効である必要があります（このサンプルでは有効化しません）。

このサンプルは Google Cloud リソースを作成しないため、`terraform destroy` で削除する対象はありません。
