# project-info (read-only)

現在の Google Cloud プロジェクトの情報（ID / number / 表示名）を読み取る最小サンプルです。
`data "google_project" "current"` を読むだけで、**Google Cloud リソースは作成・変更・削除しません**。

対象プロジェクト:

- Project ID: `nck-sakurai`
- Project Number: `1073157047557`

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `project-info` に読み替えます。
> 例: `mise exec -- terraform -chdir=packages/gc/terraform/project-info plan`

## 出力 (outputs)

`plan` / `apply` すると、対象プロジェクトに対応する以下の値が表示されます（定義は [`outputs.tf`](./outputs.tf)）。

| output | 内容 |
| --- | --- |
| `project_id` | プロジェクト ID（`nck-sakurai`） |
| `project_number` | プロジェクト番号 |
| `project_name` | プロジェクトの表示名 |

`google_project` data source が返す project number が `1073157047557` と一致しない場合、`main.tf` の `postcondition` によって `plan` がエラーになります。

このサンプルは Google Cloud リソースを作成しないため、`terraform destroy` で削除する対象はありません。
