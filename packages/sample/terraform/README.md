# sample Terraform AWS read-only example

AWS provider の認証と Terraform の基本操作を学ぶための最小サンプルです。
このサンプルは `aws_caller_identity` data source を読むだけで、AWS リソースは作成・変更・削除しません。

## 前提

- `mise run bs` が完了していること
- AWS provider が利用できる認証情報と region が設定されていること

認証情報は Terraform AWS provider の標準の仕組みを使います。例:

```bash
export AWS_PROFILE=your-profile
export AWS_REGION=ap-northeast-1
```

または一時的な環境変数を使います。

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_REGION=ap-northeast-1
```

シークレット値は repository に保存しないでください。

## 使い方

```bash
# provider plugin を取得し作業ディレクトリを初期化 (最初に一度)
mise exec -- terraform -chdir=packages/sample/terraform init

# .tf の整形ズレを検出 (書き換えず差分の有無のみ確認)
mise exec -- terraform -chdir=packages/sample/terraform fmt -check

# 構文・設定の整合性を静的チェック
mise exec -- terraform -chdir=packages/sample/terraform validate

# 実行計画を表示 (read-only サンプルなので変更は発生しない)
mise exec -- terraform -chdir=packages/sample/terraform plan

# 計画を適用し output (account ID / ARN / user ID) を表示
mise exec -- terraform -chdir=packages/sample/terraform apply
```

`apply` が成功すると、現在の認証情報に対応する AWS account ID、caller ARN、user ID が output として表示されます。

## 作成されるもの

- `.terraform.lock.hcl`: provider の選択を固定する lock file。commit 対象です。
- `.terraform/`: provider plugin などの local cache。commit しません。
- `terraform.tfstate*`: local state。commit しません。

このサンプルは AWS リソースを作成しないため、通常は `terraform destroy` で削除する対象はありません。
