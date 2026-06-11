# Design: `packages/` を `terraform/` へ改名し内側階層を畳む

- 日付: 2026-06-11
- ブランチ起点: `feature/openai-to-apps` (新規作業ブランチを切る想定)
- Issue: none (設計ドキュメントのみ)
- ステータス: レビュー待ち

## Context

直近のリファクタリング (`openai` / `cost-estimator` を `apps/` へ移設、commit `50ece73` で provider package を Terraform 専用化) により、`packages/` 配下は **Terraform サンプルのみ** を保持する状態になった。npm/Bun の package は一切存在しない。

現状構造:

```text
packages/
├── aws/
│   └── terraform/
│       ├── README.md
│       ├── caller-identity/         (read-only)
│       ├── s3-private-bucket/       (mutating)
│       ├── s3-object-upload/        (mutating)
│       └── agentcore-runtime-basic/ (mutating)
└── gc/
    └── terraform/
        ├── README.md
        ├── project-info/ ほか storage 系 / cloud-run / vertex-ai 系 (計11 operation)
```

問題点:

1. **命名と実態の乖離** — `packages/` は npm の慣習を想起させるが、中身は Terraform root module 群。`apps/` (runnable) との対比で「IaC 置き場」と一目で分かる名前が望ましい。
2. **冗長な階層** — 各 provider 配下は `terraform/` ただ1つだけ。単純 rename だと `terraform/aws/terraform/...` と terraform が二重化する。

確定事実 (調査済み):

- 各 provider 配下は `terraform/` のみ (他のサブディレクトリなし)。確度 100%。
- local state (`terraform.tfstate*`, `.terraform/`) は `.gitignore` 済みで **未追跡**。`.terraform.lock.hcl` と `*.tf` は追跡。確度 100%。
- mutating サンプルは local backend (リモートなし) に **ライブクラウドリソースの state** を保持。state 喪失 = リソース孤児化。確度 95%。
- `apps/*/uv.lock` 内の `packages/` は PyPI URL (`files.pythonhosted.org/packages/...`) の誤検出。変更対象外。確度 100%。
- CI ワークフロー (`.github/workflows/`) は存在しない。確度 100%。

## Boundaries

### Never

- `terraform.tfstate` / `.terraform/` を喪失・孤児化させない (mutating サンプルのライブリソース保護)。
- `CLAUDE.md` を直接編集しない (`AGENTS.md` への symlink。`AGENTS.md` を編集する)。
- `apps/adk-helloworld/uv.lock` / `apps/agentcore-strands-basic/uv.lock` を書き換えない (PyPI URL 誤検出)。
- ツールバージョンをドキュメントに転記しない (`mise.toml` が唯一の source of truth)。

### Always

- ディレクトリ移動は `git mv` で行い履歴を保つ (`git log --follow` が追える)。
- 移動後、各 operation の `terraform.tfstate` と `.terraform/` が新パスに存在することを検証する。
- config / CLI / docs / agent tooling を同一変更でまとめて更新する (change consistency)。
- `.claude` と `.codex` の twin (`new-package/SKILL.md`) を同期する。
- 日本語ドキュメントは英数字と日本語の間に半角スペース、数字と日本語の間にはスペースなし。

### Ask First

- mise の dev/chat/web 解決から `packages/` lookup を除去する範囲 (apps-only に簡約 ⇔ `terraform/` lookup を残す) — 本設計では apps-only を推奨。
- `.claude/rules/packages.md` のファイル名変更 (`projects.md` へ) を行うか否か。

## Architecture

採用アプローチ: **`terraform/<provider>/<operation>/`** (top-level を `terraform/` に改名し、冗長な内側 `terraform/` を畳む)。

移行後構造:

```text
terraform/
├── aws/
│   ├── README.md
│   ├── caller-identity/
│   ├── s3-private-bucket/
│   ├── s3-object-upload/
│   └── agentcore-runtime-basic/
└── gc/
    ├── README.md
    ├── project-info/
    └── ... (storage / cloud-run / vertex-ai 系)

apps/   (現状維持)
```

### ステップ 1: ディレクトリ移動 (state 保全)

```bash
mkdir -p terraform
git mv packages/aws/terraform terraform/aws   # README + 全 operation を terraform/aws/ へ (内側畳み)
git mv packages/gc/terraform  terraform/gc
rmdir packages/aws packages/gc packages        # 空になった親を削除
```

- `git mv` はディレクトリを FS rename で移動するため、未追跡の `terraform.tfstate*` / `.terraform/` も同伴する。
- 移動直後に検証: `find terraform -name terraform.tfstate | wc -l` が移動前の operation 数と一致すること。
- 安全のため、進行中の `terraform apply` がない時に実施する。

### ステップ 2: コード / config 編集

| ファイル | 変更内容 |
| --- | --- |
| `mise.toml` | `tf` タスク `-chdir=packages/aws/terraform/{{example}}` → `terraform/aws/{{example}}`。dev/chat/web の3タスクから `dir="packages/${project}"` lookup を除去し `dir="apps/${project}"` に簡約。先頭コメント (L13-14) を更新。 |
| `tools/bootstrap.sh` | `PROJECTS_DIRS=("packages" "apps")` → `("terraform" "apps")`。関連コメント (L32,37,63) を更新。 |

### ステップ 3: agent tooling 編集

| ファイル | 変更内容 |
| --- | --- |
| `.claude/rules/packages.md` → `.claude/rules/projects.md` | `paths: ["packages/**"]` → `["terraform/**", "apps/**"]`。本文の `packages/<provider>/` → `terraform/<provider>/`、内側 terraform 階層の記述を削除。 |
| `.claude/rules/mise.md` | `packages/*` の prose を `terraform/*` (+ apps) へ。 |
| `.claude/agents/env-doctor.md` | `packages/aws/ and packages/gc/` → `terraform/aws/ and terraform/gc/`。 |
| `.claude/skills/new-package/SKILL.md` | "new Terraform sample goes under `packages/<provider>/terraform/<operation>/`" → `terraform/<provider>/<operation>/`。 |
| `.codex/skills/new-package/SKILL.md` | 上記と同一変更 (twin 同期)。 |
| `.codex/hooks.json` | session reminder 文字列の `packages/` → `terraform/`。 |

### ステップ 4: ドキュメント編集 (パス参照を新構造へ)

| ファイル | 備考 |
| --- | --- |
| `AGENTS.md` | **`CLAUDE.md` ではなくこちら**。全 `packages/` 参照・ディレクトリ説明・"Add a sample" パスを更新、内側 terraform 階層の記述を削除。 |
| `README.md` | ディレクトリツリー (畳み込み反映) と "ディレクトリ構成" 節の prose。 |
| `docs/guides/{aws-cli,gcloud-cli,aws-billing,agentcore-runtime-resources}/README.md` | パス参照を更新。 |
| `docs/plans/*.md` (8ファイル) | ユーザー選択により過去の plan/design も全て新名称へ書き換え。 |
| `apps/{openai,cloud-run-rest,agentcore-strands-basic,adk-helloworld}/README.md` | Terraform サンプルへのパス参照を更新。 |
| `apps/adk-helloworld/scripts/package-agent-engine.sh` | gc adk-agent-engine への参照パスを更新。 |

### ステップ 5: 移動先 Terraform README / cleanup 編集

移動した各 README/cleanup 内の `mise exec -- terraform -chdir=packages/<provider>/terraform/<op>` / `mise run tf <op>` 例を、新パス `terraform/<provider>/<op>` (内側 terraform なし) へ更新。

- `terraform/aws/README.md` (旧 `packages/aws/terraform/README.md`) + 各 operation の `README.md` / `cleanup.md`
- `terraform/gc/README.md` + 各 operation の `README.md` / `cleanup.md`

### 変更対象外 (誤検出)

- `apps/adk-helloworld/uv.lock`, `apps/agentcore-strands-basic/uv.lock` — PyPI URL の `packages/` のため触れない。

## Acceptance Criteria

- **AC1 (構造)**: *Given* リポジトリルート, *When* `ls` を実行, *Then* `terraform/` が存在し `packages/` が存在しない。`terraform/aws/` と `terraform/gc/` 直下に operation ディレクトリと `README.md` が並び、内側 `terraform/` 階層は存在しない。
- **AC2 (state 保全)**: *Given* 移行前に存在した各 operation の `terraform.tfstate`, *When* 移行後に `find terraform -name terraform.tfstate` を実行, *Then* 移行前と同数の tfstate が新パスに存在する。
- **AC3 (参照ゼロ化)**: *Given* 全変更完了後, *When* `grep -rn "packages/" .` を node_modules / .git / `*.lock` / `.terraform/` 除外で実行, *Then* ヒット 0 件 (uv.lock の PyPI URL は除外済み)。
- **AC4 (tf タスク)**: *Given* read-only サンプル, *When* `mise run tf caller-identity plan` を実行, *Then* 新パスで正常にプランが走る (リソース変更なし)。
- **AC5 (runnable 不変)**: *Given* apps, *When* `mise run dev openai` と `mise run dev cost-estimator` を実行, *Then* 従来通り正常終了する。
- **AC6 (履歴)**: *Given* 移動した任意の `*.tf`, *When* `git log --follow` を実行, *Then* 移動前の履歴が追える。
- **AC7 (rules 反映)**: *Given* `.claude/rules/` のリネーム後ファイル, *When* `terraform/` 配下を編集, *Then* path-scoped rule が適用される (glob 更新済み)。

## Decisions Made

- **D1: top-level 名 = `terraform/`、内側 `terraform/` を畳む** (確度 88%)。ユーザーの「terraform の命名に」という意図に最も直球で合致し、`terraform/aws/terraform/` の二重化を解消。代替の `infra/` (内側維持) は将来の multi-IaC 余地を残すが現状 Terraform のみで YAGNI、`terraform/` + 内側維持は二重化が残るため不採用。
- **D2: 過去の docs/plans も全て新名称へ書き換え** (ユーザー選択)。リポジトリ全体で `packages/` 参照ゼロを達成。トレードオフとして過去記録の時点性は失われる。
- **D3: mise dev/chat/web を apps-only に簡約** (確度 80%)。`terraform/` には package.json を持つ runnable が存在しないため、`packages/` lookup は死にコード。残すと band-aid になるため除去 (Ask First 対象。維持したい場合は要相談)。
- **D4: `.claude/rules/packages.md` → `projects.md` にリネーム** (確度 70%)。内容が packages/apps 両方の規約のためファイル名を実態に合わせる。glob も `terraform/**` + `apps/**` に更新 (Ask First 対象)。
- **D5: state はディレクトリ単位 `git mv` で同伴 + 移動後検証** (確度 90%)。`git mv` の FS rename で未追跡 state も移動するが、孤児化防止のため AC2 で明示検証。

## Open Questions

- `mise.toml` の `tf` タスクは現状 AWS 専用 (`-chdir=terraform/aws/...`)。gc は直接実行。本リネームではこの非対称を踏襲する (汎用化は別件)。問題なければこのまま。
- `.claude/rules/packages.md` のリネーム可否 (D4) — リネームせず glob と本文のみ更新でも可。

## Non-Goals

- `tf` タスクの provider 汎用化 (gc 対応・provider 引数化)。
- Terraform リモート backend の導入。
- サンプルの追加・削除・内容変更。
- `apps/` 構造の変更。
- ブランチ `feature/openai-to-apps` 上の既存コミットの書き換え。
