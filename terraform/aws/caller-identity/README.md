# caller-identity (read-only)

現在の AWS 認証情報の「呼び出し元 (caller) は誰か」を読み取る最小サンプルです。
`data "aws_caller_identity" "current"` を読むだけで、**AWS リソースは作成・変更・削除しません**。

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `caller-identity` に読み替えます。
> 例: `mise exec -- terraform -chdir=packages/aws/terraform/caller-identity plan`

## 出力 (outputs)

`plan` / `apply` すると、現在の認証情報に対応する以下の値が表示されます（定義は [`outputs.tf`](./outputs.tf)）。

| output | 内容 |
| --- | --- |
| `account_id` | AWS アカウント ID |
| `caller_arn` | 使用中の IAM プリンシパルの ARN |
| `caller_user_id` | その一意なユーザー ID |

このサンプルは AWS リソースを作成しないため、`terraform destroy` で削除する対象はありません。
