# Terraform AWS サンプル集

AWS provider の認証と Terraform の基本操作を学ぶための、自己完結したサンプル集です。
各サンプルは `terraform/` 直下の `<operation>/` に**独立した root module** として置かれ、それぞれ単独で `init` / `plan` / `apply` できます（state もサンプルごとに分離されるため、あるサンプルの操作が他へ波及しません）。

## サンプル一覧

| サンプル | 種別 | 説明 |
| --- | --- | --- |
| [caller-identity](./caller-identity/) | read-only | STS caller identity（account ID / ARN / user ID）を読む最小サンプル |
| [s3-private-bucket](./s3-private-bucket/) | mutating | `aws_s3_bucket` で private S3 bucket を1つ作成し、`destroy` まで lifecycle を学ぶ |
| [s3-object-upload](./s3-object-upload/) | mutating | `aws_s3_object` で既存 bucket に local file を1つ upload し、object cleanup まで学ぶ |

新しいサンプルは `terraform/` 直下にディレクトリを 1 つ足し、この表に 1 行追加します（`<operation>` は `s3-bucket-list` のような kebab-case の「対象 + 操作」）。read-only は名詞 / `*-list` / `*-read`、リソースを作成する mutating はリソース名中心で命名し、本表の「種別」列で区別します。

## 学習順序

read-only の基礎から、低リスクな mutating（リソース作成）へ段階的に進む構成です。

1. [caller-identity](./caller-identity/) — provider 設定 / AWS 認証 / `aws_caller_identity` / outputs を学ぶ。
2. [s3-private-bucket](./s3-private-bucket/) — `plan` / `apply` / `state` / `destroy` を private S3 bucket 1つで学ぶ。
3. [s3-object-upload](./s3-object-upload/) — 既存 bucket に local file を object として upload し、object と bucket の cleanup 順序を学ぶ。
4. `iam-policy-document`（未追加） — policy JSON の組み立てを read-only で学ぶ。
5. `s3-bucket-policy`（未追加） — bucket policy の attachment と least privilege を学ぶ。

## 種別ごとの扱い（read-only / mutating）

- **read-only**: data source を読むだけで、リソースの作成・変更・削除はしません。`destroy` で消す対象もありません。
- **mutating**: AWS の状態（有効な API やリソース）を変更します。**学習後は各サンプルの README に従って `destroy` してください**。
  - [s3-private-bucket](./s3-private-bucket/) は private S3 bucket を作成します。bucket 名が衝突した場合は `bucket_prefix` を変えて再実行してください。
  - [s3-object-upload](./s3-object-upload/) は既存 bucket に object を作成します。bucket を削除する前に、このサンプルの [`cleanup.md`](./s3-object-upload/cleanup.md) で object を先に削除してください。

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

`<example>` を実際のサンプル名（例: `caller-identity`）に置き換えて実行します。

mise ラッパータスク（推奨・短い記法）:

```bash
mise run tf <example> init        # provider plugin を取得し作業ディレクトリを初期化 (最初に一度)
mise run tf <example> fmt -check  # .tf の整形ズレを検出 (書き換えず差分の有無のみ確認)
mise run tf <example> validate    # 構文・設定の整合性を静的チェック
mise run tf <example> plan        # 実行計画を表示
mise run tf <example> apply       # 計画を適用し output を表示
mise run tf <example> destroy     # mutating サンプルで作成したリソースを削除
```

terraform を直接呼ぶ場合（同義）:

```bash
mise exec -- terraform -chdir=packages/aws/terraform/<example> init
mise exec -- terraform -chdir=packages/aws/terraform/<example> plan
```

## 各サンプルが生成するファイル

- `.terraform.lock.hcl`: provider の選択を固定する lock file。**commit 対象**です。
- `.terraform/`: provider plugin などの local cache。commit しません。
- `terraform.tfstate*`: local state。commit しません。
- `terraform.tfvars` / `*.tfvars`: 変数を渡す local 値。**commit しません**。
- `terraform.tfvars.template`: `.tfvars` の雛形。プレースホルダのみを含む場合は **commit 対象**です。

`.gitignore` はリポジトリ全体で上記 runtime ファイル（`.tfvars` を含む）を（任意のネスト深さで）無視し、`*.template` だけを追跡対象に残すため、`terraform/` 配下にサンプルを増やしても gitignore の追加設定は不要です。
