# workshop

クラウド / IaC 学習用のモノレポです。`packages/` 配下に独立したプロジェクトを並べ、ツールのバージョンを [mise](https://mise.jdx.dev/) で一元管理します。

## 必要なツール

| ツール | 用途 | 管理方法 |
| --- | --- | --- |
| [mise](https://mise.jdx.dev/getting-started.html) | ツールバージョン管理・タスクランナー | 手動インストール |
| [bun](https://bun.sh/) | JavaScript / TypeScript ランタイム | mise 管理 |
| [terraform](https://developer.hashicorp.com/terraform) | IaC | mise 管理 |
| [aws-cli](https://docs.aws.amazon.com/cli/) | AWS 操作 CLI（[基本コマンド](./docs/guides/aws-cli/README.md)） | mise 管理 |
| [python](https://www.python.org/) | AgentCore Runtime direct code deployment 用 app | mise 管理 |
| [uv](https://docs.astral.sh/uv/) | Python 依存 lock / package 生成 | mise 管理 |

> バージョンは [`mise.toml`](./mise.toml) で固定管理しています（README には転記しません）。

## ディレクトリ構成

```text
workshop/
├── mise.toml            # ツールのバージョン + タスク定義
├── tools/
│   ├── bootstrap.sh     # 全環境のセットアップスクリプト
│   └── git-hooks/       # git フック (commit-msg: Conventional Commits 検証)
└── packages/            # プロジェクト群 (この配下が bootstrap の対象。dev / dev:all は直下のプロジェクトのみ)
    ├── aws/
    │   ├── apps/
    │   │   └── agentcore-strands-basic/   # AgentCore Runtime に deploy する Python + Strands Agents app
    │   ├── cost-estimator/           # 見積もり専用 catalog + bcm-pricing-calculator API adapter
    │   └── terraform/
    │       ├── README.md             # サンプル一覧と共通手順
    │       ├── agentcore-runtime-basic/  # AgentCore Runtime + Strands Agents app を deploy する mutating サンプル
    │       ├── caller-identity/      # AWS 操作ごとの独立した read-only サンプル (caller identity を読む)
    │       ├── s3-private-bucket/    # private S3 bucket を作成し destroy まで学ぶ mutating サンプル
    │       └── s3-object-upload/     # 既存 S3 bucket に object を upload する mutating サンプル
    ├── gc/
    │   ├── apps/
    │   │   ├── adk-helloworld/       # Google ADK の最小 HelloWorld agent (ローカル実行 + Agent Engine deploy 用 source archive 生成)
    │   │   └── cloud-run-rest/       # Cloud Run に deploy する最小の Bun REST service (Dockerfile 付き)
    │   └── terraform/
    │       ├── README.md             # サンプル一覧と共通手順
    │       ├── project-info/         # Google Cloud 操作ごとの独立した read-only サンプル (project nck-sakurai を読む)
    │       ├── cloud-run-service-basic/  # Artifact Registry + private Cloud Run service を作る mutating サンプル
    │       └── adk-agent-engine-basic/   # ADK agent を Vertex AI Agent Engine へ deploy する mutating サンプル
    └── openai/              # OpenAI Agents SDK (TypeScript) の最小 HelloWorld サンプル (Agent + run、key 未設定時は案内して exit 0)
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
| `chat` | プロジェクトの対話チャットを起動 | `mise run chat openai` |
| `web` | プロジェクトの Web チャット UI を起動 | `mise run web openai` |
| `bootstrap` (alias `bs`) | 全環境の依存セットアップ | `mise run bs` |
| `install-hooks` | git commit-msg フックを有効化 | `mise run install-hooks` |

```bash
mise run dev aws      # <name> を個別実行 (aws / gc / openai)
mise run dev:all      # まとめて実行
mise run chat openai  # openai とターミナルで対話チャット
mise run web openai   # openai の Web チャット UI (ブラウザ)
mise tasks            # 登録済みタスク一覧
```

### Terraform サンプル

- AWS: [`packages/aws/terraform/README.md`](./packages/aws/terraform/README.md)
- Google Cloud: [`packages/gc/terraform/README.md`](./packages/gc/terraform/README.md)

### ガイド

各種操作の手順は [`docs/guides/`](./docs/guides/) にまとめています。

- [AWS CLI 基本コマンド](./docs/guides/aws-cli/README.md)
- [AWS CLI 認証情報の設定](./docs/guides/aws-cli-credentials/README.md)
- [IAM ユーザー作成とアクセスキー取得手順](./docs/guides/aws-iam-user-creation/README.md)
- [AWS 課金・コストの確認](./docs/guides/aws-billing/README.md)
- [AgentCore Runtime sample が作る AWS リソース](./docs/guides/agentcore-runtime-resources/README.md)
- [gcloud CLI 基本コマンド](./docs/guides/gcloud-cli/README.md)

## プロジェクトの追加

1. `packages/<name>/` を作成し、`package.json`（`scripts.start` を定義）と実装を置く
2. `mise run bs` で依存をインストール
3. `mise run dev <name>` で実行

`dev:all` と `bootstrap` は `packages/*` を自動で走査するため、追加後にタスクや設定を書き換える必要はありません。
