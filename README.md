# workshop

クラウド / IaC 学習用のモノレポです。`packages/` 配下に独立したプロジェクトを並べ、ツールのバージョンを [mise](https://mise.jdx.dev/) で一元管理します。

## 必要なツール

| ツール | 用途 | 管理方法 |
| --- | --- | --- |
| [mise](https://mise.jdx.dev/getting-started.html) | ツールバージョン管理・タスクランナー | 手動インストール |
| [bun](https://bun.sh/) | JavaScript / TypeScript ランタイム | mise 管理 |
| [terraform](https://developer.hashicorp.com/terraform) | IaC | mise 管理 |
| [aws-cli](https://docs.aws.amazon.com/cli/) | AWS 操作 CLI（[基本コマンド](./docs/guides/aws-cli/README.md)） | mise 管理 |

> バージョンは [`mise.toml`](./mise.toml) で固定管理しています（README には転記しません）。

## ディレクトリ構成

```text
workshop/
├── mise.toml            # ツールのバージョン + タスク定義
├── tools/
│   └── bootstrap.sh     # 全環境のセットアップスクリプト
└── packages/            # プロジェクト群 (この配下が bootstrap / dev の対象)
    ├── aws/
    ├── gc/
    └── sample/
        └── terraform/   # AWS caller identity を読む read-only Terraform サンプル
```

`packages/` 配下の各プロジェクトは `bun` のバージョンを root の `mise.toml` から継承します。特定プロジェクトだけ別ツール / バージョンが必要な場合は、そのフォルダに `mise.toml` を置くと差分だけ上書きできます。

## セットアップ

前提として [mise をインストール](https://mise.jdx.dev/getting-started.html)しておきます。

```bash
# 全環境を一括セットアップ (推奨)
mise run bs
```

`mise run bs`（= `bootstrap`）は次を実行します。

1. root のツールを `mise install`
2. `packages/*` の各プロジェクトで `mise install`（固有 `mise.toml` がある場合のみ）
3. `packages/*` の各プロジェクトで `bun install`（`package.json` がある場合）

### shell への activate（推奨）

activate しておくと `mise exec -- ` を付けずに `bun` を直接呼べます。

```bash
# ~/.zshrc に追記
eval "$(mise activate zsh)"
```

## 使い方

| タスク | 用途 | 例 |
| --- | --- | --- |
| `dev` | プロジェクトを指定して実行 | `mise run dev aws` |
| `dev:all` | `packages/` 配下を全実行 | `mise run dev:all` |
| `bootstrap` (alias `bs`) | 全環境の依存セットアップ | `mise run bs` |

```bash
mise run dev aws      # aws / gc / sample を個別実行
mise run dev:all      # まとめて実行
mise tasks            # 登録済みタスク一覧
```

### Terraform サンプル

`packages/sample/terraform/` に、AWS provider の認証と Terraform の基本操作を学ぶための read-only サンプルがあります。
`aws_caller_identity` data source を読むだけなので、AWS リソースは作成・変更・削除しません。

手順は [`packages/sample/terraform/README.md`](./packages/sample/terraform/README.md) を参照してください。

### AWS CLI

AWS の操作には mise 管理の AWS CLI を使います。認証 (`aws login` / アクセスキー) や認証情報の設定、疎通確認 (`aws sts get-caller-identity`)、基本コマンドは [`docs/guides/aws-cli/README.md`](./docs/guides/aws-cli/README.md) を参照してください。

## プロジェクトの追加

1. `packages/<name>/` を作成し、`package.json`（`scripts.start` を定義）と実装を置く
2. `mise run bs` で依存をインストール
3. `mise run dev <name>` で実行

`dev:all` と `bootstrap` は `packages/*` を自動で走査するため、追加後にタスクや設定を書き換える必要はありません。
