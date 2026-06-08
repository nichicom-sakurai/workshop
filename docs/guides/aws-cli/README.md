# AWS CLI 基本コマンド

このリポジトリで使う AWS CLI の最小コマンド集です。バージョンは [`mise.toml`](../../../mise.toml) で固定管理しています（README には転記しません）。

## 前提

- `mise run bs` が完了していること（AWS CLI も mise 管理ツールとして install されます）
- AWS への認証ができること。次の 2 通りの方法があります。
  - **A. `aws login` でコンソールのサインインを使う方法**: AWS Management Console にサインインできれば、ブラウザ経由で一時認証情報を取得できます。IAM Identity Center (SSO) の事前設定が不要で、refresh token により自動更新されるため、ローカル開発・学習にはこれが手軽です。アクセスキーを長期保管しないため推奨です。
    ```bash
    mise exec -- aws login --profile work                   # ブラウザでサインインし一時認証情報を取得
    mise exec -- aws sts get-caller-identity --profile work # 疎通確認
    ```
    > `aws login` は比較的新しいコマンドです（バージョンは [`mise.toml`](../../../mise.toml) で固定済み）。`default` profile に既にアクセスキーが設定済みだと拒否されるため、`--profile <名前>` を付けて別 profile に取得します。リモート (SSH) など browser が無い環境では `--remote` を付け、表示された URL とコードで認証します。
    > 組織で IAM Identity Center (SSO) を運用している場合は、`aws configure sso` で profile を設定し `aws sso login` を使う方法もあります。
  - **B. IAM ユーザーを作成してアクセスキーを取得する方法**: AWS Management Console で IAM ユーザーを作成し、アクセスキー（Access key ID / Secret access key）を発行します。発行したキーは「[認証情報の設定](../aws-cli-credentials/README.md)」で CLI に設定します。画像付きの作成手順は [IAM ユーザー作成とアクセスキー取得手順](../aws-iam-user-creation/README.md) を参照してください。

## 認証情報の設定

前提 **B（IAM ユーザーのアクセスキー）** の環境変数 / profile / `aws configure` による設定手順は [AWS CLI 認証情報の設定](../aws-cli-credentials/README.md) を参照してください。前提 A（`aws login`）を使う場合は一時認証情報が自動で取得・更新されるため、設定は不要です。

## 基本コマンド

```bash
mise exec -- aws --version                 # バージョン確認
mise exec -- aws sts get-caller-identity   # 認証情報に対応する account / ARN / user ID を確認
mise exec -- aws configure list-profiles   # 利用可能な profile 一覧
```

> `aws sts get-caller-identity` は認証が通っているかの疎通確認に便利です。
> `packages/sample/terraform/` の read-only Terraform サンプルと同じ認証情報で動作確認できます。
