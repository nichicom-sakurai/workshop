# AWS CLI 認証情報の設定

IAM ユーザーのアクセスキーを使って AWS CLI に認証情報を設定する手順です（[AWS CLI 基本コマンド](../aws-cli/README.md) の「前提 B」向け）。

> [INFO] 前提 A（`aws login`）を使う場合は一時認証情報が自動で取得・更新されるため、本ドキュメントの設定は不要です。
> アクセスキー自体の発行手順は [IAM ユーザー作成とアクセスキー取得手順](../aws-iam-user-creation/README.md) を参照してください。

> [WARNING] シークレット値は repository に保存しないでください。環境変数または profile を使い、`.local` ファイルや環境変数で管理します。

## 1. 環境変数で渡す

一時的に使う場合や CI などでは環境変数が手軽です。

```bash
# 一時的な認証情報を環境変数で渡す
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_REGION=ap-northeast-1

# または named profile を使う
export AWS_PROFILE=your-profile
export AWS_REGION=ap-northeast-1
```

## 2. `aws configure` で対話的に設定

`~/.aws/credentials` / `~/.aws/config` に保存して継続利用する場合に使います。

```bash
mise exec -- aws configure                 # default profile を対話設定
mise exec -- aws configure --profile work  # named profile を対話設定
mise exec -- aws configure list            # 現在の設定を確認
```

## 3. 疎通確認

設定後、認証が通るか確認します。

```bash
mise exec -- aws sts get-caller-identity   # account / ARN / user ID を確認
```

## 後始末（推奨）

使わなくなったアクセスキーは IAM の **セキュリティ認証情報** から無効化 / 削除し、不要な長期認証情報を残さないようにします。定期的なローテーションも推奨です。
