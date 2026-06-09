# Terraform AWS サンプル集

AWS provider の認証と Terraform の基本操作を学ぶための、自己完結したサンプル集です。
各サンプルは `terraform/` 直下の `<operation>/` に**独立した root module** として置かれ、それぞれ単独で `init` / `plan` / `apply` できます（state もサンプルごとに分離されるため、あるサンプルの操作が他へ波及しません）。

## サンプル一覧

| サンプル | 種別 | 説明 |
| --- | --- | --- |
| [caller-identity](./caller-identity/) | read-only | STS caller identity（account ID / ARN / user ID）を読む最小サンプル |

新しいサンプルは `terraform/` 直下にディレクトリを 1 つ足し、この表に 1 行追加します（`<operation>` は `s3-bucket-list` のような kebab-case の「対象 + 操作」）。read-only は名詞 / `*-list` / `*-read`、リソースを作成する mutating はリソース名中心で命名し、本表の「種別」列で区別します。

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

`.gitignore` はリポジトリ全体で上記 runtime ファイルを（任意のネスト深さで）無視するため、`terraform/` 配下にサンプルを増やしても gitignore の追加設定は不要です。
