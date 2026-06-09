# gc Terraform Google Cloud read-only example

Google Cloud provider の認証と Terraform の基本操作を学ぶための最小サンプルです。
このサンプルは `google_project` data source を読むだけで、Google Cloud リソースは作成・変更・削除しません。

対象プロジェクト:

- Project ID: `nck-sakurai`
- Project Number: `1073157047557`

## 前提

- `mise run bs` が完了していること
- `nck-sakurai` を読める Google Cloud の認証情報があること
- 対象プロジェクトで Cloud Resource Manager API が有効であること（このサンプルでは有効化しません）

認証は Application Default Credentials (ADC) など、Terraform Google provider の標準の仕組みを使います。例:

```bash
gcloud auth application-default login
```

シークレット値は repository に保存しないでください。

## 使い方

```bash
mise exec -- terraform -chdir=packages/gc/terraform init
mise exec -- terraform -chdir=packages/gc/terraform fmt -check
mise exec -- terraform -chdir=packages/gc/terraform validate
mise exec -- terraform -chdir=packages/gc/terraform plan
```

`plan` が成功すると、`nck-sakurai` の Project ID / Project Number / 表示名が plan の出力（`Changes to Outputs`）に表示され、Google Cloud リソースの create/update/destroy が発生しないことを確認できます。

`google_project` data source が返す project number が `1073157047557` と一致しない場合、`main.tf` の `postcondition` によって `plan` がエラーになります。

## 作成されるもの

- `.terraform.lock.hcl`: provider の選択を固定する lock file。commit 対象です。
- `.terraform/`: provider plugin などの local cache。commit しません。
- `terraform.tfstate*`: local state。commit しません。

このサンプルは Google Cloud リソースを作成しないため、通常は `terraform destroy` で削除する対象はありません。
