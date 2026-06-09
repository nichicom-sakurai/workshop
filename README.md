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
│   ├── bootstrap.sh     # 全環境のセットアップスクリプト
│   └── git-hooks/       # git フック (commit-msg: Conventional Commits 検証)
└── packages/            # プロジェクト群 (この配下が bootstrap / dev の対象)
    ├── aws/
    │   └── terraform/
    │       └── examples/             # AWS 操作ごとの独立した Terraform サンプル
    │           └── caller-identity/  # caller identity を読む read-only サンプル
    └── gc/
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
4. git フックを有効化（`core.hooksPath` を `tools/git-hooks` に設定）

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
| `install-hooks` | git commit-msg フックを有効化 | `mise run install-hooks` |

```bash
mise run dev aws      # aws / gc を個別実行
mise run dev:all      # まとめて実行
mise tasks            # 登録済みタスク一覧
```

### Terraform サンプル

`packages/aws/terraform/examples/<operation>/` に、AWS 操作ごとの自己完結した Terraform サンプルを並べています。各サンプルは独立した root module で、`mise run tf <operation> <command>`（例: `mise run tf caller-identity plan`）で個別に実行できます。最初のサンプル `caller-identity` は `aws_caller_identity` を読むだけの read-only サンプル（AWS リソースは作成・変更・削除しません）です。

サンプル一覧と共通手順は [`packages/aws/terraform/README.md`](./packages/aws/terraform/README.md) を参照してください。

### AWS CLI

AWS の操作には mise 管理の AWS CLI を使います。認証 (`aws login` / アクセスキー) や認証情報の設定、疎通確認 (`aws sts get-caller-identity`)、基本コマンドは [`docs/guides/aws-cli/README.md`](./docs/guides/aws-cli/README.md) を参照してください。

## コミット規約

コミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/) 形式（`<type>(<scope>): <説明>`）で書きます。`mise run bs` で有効化される commit-msg フック（`tools/git-hooks/commit-msg`、依存ゼロの bash スクリプト）が、形式・type・subject 72 文字以内を自動チェックします。

- `type`: `feat` / `fix` / `docs` / `style` / `refactor` / `perf` / `test` / `build` / `chore` / `ci` / `revert`
- `scope`: 任意（例: `aws` / `gc`）。強制はしません。
- 例: `feat(aws): S3 バケット一覧タスクを追加`、`docs: README を更新`

`bs` を実行していないクローンでフックだけ有効化するには `mise run install-hooks` を実行します。

## プロジェクトの追加

1. `packages/<name>/` を作成し、`package.json`（`scripts.start` を定義）と実装を置く
2. `mise run bs` で依存をインストール
3. `mise run dev <name>` で実行

`dev:all` と `bootstrap` は `packages/*` を自動で走査するため、追加後にタスクや設定を書き換える必要はありません。
