# terraform ディレクトリ改名 実装計画

**Goal:** `packages/<provider>/terraform/<operation>/` を `terraform/<provider>/<operation>/` へ改名し (内側 `terraform/` 階層を畳む)、リポジトリ全体の参照を追従させる。

**Architecture:** `git mv` でディレクトリを移動 (local state を保全) し、`mise.toml` / `bootstrap.sh` / agent tooling / ドキュメントの順に参照を更新する。テストランナーが無いため各タスクは「変更 → 検証コマンド → コミット」の **検証ファースト** 構造を取る (rename にユニットテストは書けないため TDD の test-after に相当)。

**Tech Stack:** mise (タスク/バージョン管理) + terraform 1.15.5 + bun 1.3.14 + python/uv。テスト/lint/typecheck のリポジトリ横断タスクは無し。検証は `mise run` 実行と `grep`。

**Design Document:** [docs/plans/2026-06-11-terraform-dir-rename-design.md](./2026-06-11-terraform-dir-rename-design.md)

**Recommended Execution:** Loop (HITL) — 6タスク。Task 2 (移動) に state 保全検証ゲートがあるため各タスク後に確認するのが安全。

---

## 前提・不変条件 (全タスク共通)

- **Never**: `terraform.tfstate*` / `.terraform/` を喪失させない (mutating サンプルのライブリソース保護)。`CLAUDE.md` を直接編集しない (`AGENTS.md` への symlink)。`apps/*/uv.lock` を編集しない (PyPI URL `files.pythonhosted.org/packages/...` の誤検出)。
- **Always**: ディレクトリ移動は `git mv` (履歴保持)。日本語は英数字との間に半角スペース、数字と日本語間はスペースなし。
- **コミット規約**: `<type>(<scope>): <説明>` — type は `feat|fix|docs|style|refactor|perf|test|build|chore|ci|revert`、scope 任意 (`[a-z0-9._/-]+`)、subject ≤72 文字 (`wc -m`)。フックは `tools/git-hooks/commit-msg`。

### パス置換ルール (ドキュメント編集タスクで使用)

順序を守って適用する (specific を先に処理):

1. `packages/aws/terraform/` → `terraform/aws/`
2. `packages/gc/terraform/` → `terraform/gc/`
3. `packages/aws/` → `terraform/aws/`
4. `packages/gc/` → `terraform/gc/`
5. 残りの `packages/` → `terraform/`
6. 散文の `packages/<provider>/terraform/<operation>/` 表現 → `terraform/<provider>/<operation>/`

> **置換対象外 (除外)**: `docs/plans/2026-06-11-terraform-dir-rename-design.md` と本計画ファイル `docs/plans/2026-06-11-terraform-dir-rename-plan.md`。この2件は本マイグレーションの「移行元 `packages/`」を記述するため置換すると意味が崩壊する。`apps/adk-helloworld/uv.lock` / `apps/agentcore-strands-basic/uv.lock` も除外 (PyPI URL)。

---

### Task 1: 設計・計画ドキュメントをコミット (作業ツリーをクリーン化)

構造変更の前に planning 成果物をコミットし、`git mv` の差分を純粋な rename に保つ。

**Files:**

- Add: `docs/plans/2026-06-11-terraform-dir-rename-design.md` (既存・未コミット)
- Add: `docs/plans/2026-06-11-terraform-dir-rename-plan.md` (本ファイル)

**Step 1: 対象を確認**

Run: `git status --porcelain docs/plans/`
Expected: 上記2ファイルが `??` (untracked) で表示される。

**Step 2: コミット**

```bash
git add docs/plans/2026-06-11-terraform-dir-rename-design.md \
        docs/plans/2026-06-11-terraform-dir-rename-plan.md
git commit -m "docs(plans): terraform ディレクトリ改名の設計・計画を追加"
```

**Step 3: 検証**

Run: `git status --porcelain`
Expected: 出力なし (作業ツリーがクリーン)。フックが `[OK] commit message は Conventional Commits 形式です。` を出力。

---

### Task 2: ディレクトリ移動と state 保全検証

`packages/<provider>/terraform/` を `terraform/<provider>/` へ移動し内側階層を畳む。local state (gitignore 済み・未追跡) は `git mv` のディレクトリ rename で同伴する。

**Files:**

- Move: `packages/aws/terraform/` → `terraform/aws/`
- Move: `packages/gc/terraform/` → `terraform/gc/`
- Delete (空ディレクトリ): `packages/aws/`, `packages/gc/`, `packages/`

**Step 1: 移動前の tfstate 件数を記録**

```bash
before=$(find packages -name 'terraform.tfstate' | wc -l | tr -d ' ')
echo "before tfstate count: ${before}"   # 期待値: 15
```

**Step 2: 移動を実行**

```bash
mkdir -p terraform
git mv packages/aws/terraform terraform/aws
git mv packages/gc/terraform  terraform/gc
rmdir packages/aws packages/gc packages
```

**Step 3: 検証 (state 保全が最重要)**

```bash
# 構造: terraform/{aws,gc}/<operation>/ が並び、packages/ が消えていること
test ! -e packages && echo "[OK] packages/ 削除済み" || echo "[NG] packages/ 残存"
ls terraform/aws terraform/gc

# state 件数が移動前と一致すること (AC2)
after=$(find terraform -name 'terraform.tfstate' | wc -l | tr -d ' ')
echo "after tfstate count: ${after}"
[ "${after}" = "${before}" ] && echo "[OK] tfstate 保全" || echo "[NG] tfstate 件数不一致"

# 内側 terraform/ が畳まれ二重化していないこと
test ! -e terraform/aws/terraform && echo "[OK] 内側 terraform/ なし" || echo "[NG] 二重化"

# 履歴が追えること (AC6)
git log --oneline --follow -1 terraform/aws/caller-identity/main.tf
```

Expected: `[OK]` が並び、`after` == `before` (=15)、`git log --follow` が移動前の履歴を返す。

> **[NG] 時の対処**: `after` < `before` の場合のみ、未移動の tfstate を手動補完 (`git mv` のディレクトリ rename で通常は発生しない)。`terraform apply` 進行中でないことを確認してから再実行。

**Step 4: コミット**

```bash
git add -A
git commit -m "refactor(terraform): packages/ を terraform/ 構造へ移動し階層を畳む"
```

> tfstate / `.terraform/` は gitignore 済みのためコミットには含まれない (リネームされた `.tf` / `.terraform.lock.hcl` / `README.md` / `cleanup.md` が `R` で記録される)。

---

### Task 3: mise.toml と bootstrap.sh を新構造へ追従

`tf` タスクのパスを更新し、dev/chat/web の解決を apps-only に簡約 (`packages/` lookup は移動後に死にコードのため除去 = 設計 D3)。bootstrap の走査対象を更新。

**Files:**

- Modify: `mise.toml`
- Modify: `tools/bootstrap.sh`

**Step 1: `mise.toml` を編集**

(a) コメントブロック (L13-15):

```diff
-# --- 実行タスク (runnable プロジェクトを packages/ → apps/ の順に解決) ---
-# packages/<provider> は Terraform 置き場で package.json を持たないため解決対象外。
+# --- 実行タスク (runnable プロジェクトを apps/ から解決) ---
+# terraform/<provider> は Terraform 置き場で package.json を持たないため解決対象外。
 # runnable な app は apps/ 配下 (openai / cost-estimator など)。
```

(b) dev/chat/web の解決行 (3箇所同一・全置換):

```diff
-project="{{arg(name='project')}}"; dir="packages/${project}"; [ -f "${dir}/package.json" ] || dir="apps/${project}"
+project="{{arg(name='project')}}"; dir="apps/${project}"
```

(c) dev/chat/web のエラーメッセージ (3箇所同一・全置換):

```diff
-[ -f "${dir}/package.json" ] || { echo "[NG] runnable project が見つかりません: ${project} (packages/ と apps/ を確認)" >&2; exit 1; }
+[ -f "${dir}/package.json" ] || { echo "[NG] runnable project が見つかりません: ${project} (apps/ を確認)" >&2; exit 1; }
```

(d) `tf` タスクのパス (L45):

```diff
-run = "mise exec -- terraform -chdir=packages/aws/terraform/{{arg(name='example')}} {{arg(name='command', var=true)}}"
+run = "mise exec -- terraform -chdir=terraform/aws/{{arg(name='example')}} {{arg(name='command', var=true)}}"
```

**Step 2: `tools/bootstrap.sh` を編集**

```diff
-PROJECTS_DIRS=("packages" "apps")
+PROJECTS_DIRS=("terraform" "apps")
```

コメント/echo の `packages/* と apps/*` / `packages/* and apps/*` (L32, L37, L63) を `terraform/* と apps/*` / `terraform/* and apps/*` に置換。

**Step 3: 検証**

```bash
# tf タスクが新パスで動く (read-only サンプルなので安全 / AC4)
mise run tf caller-identity plan

# runnable app が従来通り動く (AC5)
mise run dev openai
mise run dev cost-estimator

# bootstrap が走査エラーを出さない (再実行は冪等)
mise run bs

# この2ファイルに packages/ が残っていない
grep -n "packages/" mise.toml tools/bootstrap.sh || echo "[OK] no packages/ refs"
```

Expected: `tf ... plan` がリソース変更なしで完了、`dev` 2件が正常終了、`bs` が `[OK]`、grep が `[OK] no packages/ refs`。

**Step 4: コミット**

```bash
git add mise.toml tools/bootstrap.sh
git commit -m "refactor(mise): tf タスクと bootstrap を terraform/ 構造へ追従"
```

---

### Task 4: agent tooling (.claude / .codex) を新構造へ追従

path-scoped rule の glob とファイル名、各種参照を更新。`.claude` と `.codex` の twin (`new-package/SKILL.md`) を同期。

**Files:**

- Move + Modify: `.claude/rules/packages.md` → `.claude/rules/projects.md`
- Modify: `.claude/rules/mise.md`
- Modify: `.claude/agents/env-doctor.md`
- Modify: `.claude/skills/new-package/SKILL.md`
- Modify: `.codex/skills/new-package/SKILL.md`
- Modify: `.codex/hooks.json`

**Step 1: rules ファイルをリネーム (設計 D4)**

```bash
git mv .claude/rules/packages.md .claude/rules/projects.md
```

**Step 2: `.claude/rules/projects.md` を編集**

- frontmatter glob: `- "packages/**"` → `- "terraform/**"` (`- "apps/**"` は維持)
- 見出し `# packages/ & apps/ conventions` → `# terraform/ & apps/ conventions`
- 本文: パス置換ルール 1-6 を適用。特に:
  - `packages/<provider>/ holds provider Terraform-sample containers (just terraform/<operation>/; ...)` → `terraform/<provider>/ holds provider Terraform-sample roots (one <operation>/ per cloud operation; ...)`
  - `resolve a runnable <name> ... from packages/ then apps/` (2箇所) → `... from apps/` (Task 3 の apps-only 簡約に整合)
  - `auto-discovers packages/ + apps/` → `auto-discovers terraform/ + apps/`
  - `Terraform-sample container: packages/aws/` → `terraform/aws/`
  - `A new Terraform sample goes under packages/<provider>/terraform/<operation>/` → `terraform/<provider>/<operation>/`

**Step 3: 残りの agent tooling を編集**

- `.claude/rules/mise.md`: `A project-local mise.toml (under packages/* or any subdir)` → `(under terraform/*, apps/*, or any subdir)`
- `.claude/agents/env-doctor.md`: `packages/aws/ and packages/gc/` → `terraform/aws/ and terraform/gc/` (出現箇所すべて)
- `.claude/skills/new-package/SKILL.md`: `packages/<provider>/terraform/<operation>/` → `terraform/<provider>/<operation>/`
- `.codex/skills/new-package/SKILL.md`: 上と同一変更 (twin 同期)
- `.codex/hooks.json`: reminder 文字列内の `packages/` → 置換ルールを適用

**Step 4: 検証**

```bash
test -f .claude/rules/projects.md && test ! -e .claude/rules/packages.md && echo "[OK] rename"
grep -rn "packages/" .claude/ .codex/ || echo "[OK] no packages/ refs in agent tooling"
```

Expected: `[OK] rename` と `[OK] no packages/ refs in agent tooling`。

**Step 5: コミット**

```bash
git add -A .claude/ .codex/
git commit -m "refactor(agents): .claude/.codex の参照を terraform/ 構造へ追従"
```

---

### Task 5: README / AGENTS と移動済み terraform README を新構造へ更新

リポジトリの正準な構造記述 (人間向け README + AI 向け AGENTS) と、移動済みサンプルの README/cleanup を更新。

**Files:**

- Modify: `README.md`
- Modify: `AGENTS.md` (**`CLAUDE.md` は編集しない** — symlink)
- Modify: `terraform/aws/README.md`, `terraform/gc/README.md` および各 operation の `README.md` / `cleanup.md` (Task 2 で移動済み)

**Step 1: `README.md` のディレクトリツリーを置換**

`packages/` ブロックを以下に置換 (内側 `terraform/` を畳む):

```text
└── terraform/         # provider ごとの Terraform サンプル置き場 (provider 配下に operation を直置き)
    ├── aws/
    │   ├── README.md             # サンプル一覧と共通手順
    │   ├── agentcore-runtime-basic/  # AgentCore Runtime + Strands Agents app を deploy する mutating サンプル
    │   ├── caller-identity/      # AWS 操作ごとの独立した read-only サンプル (caller identity を読む)
    │   ├── s3-private-bucket/    # private S3 bucket を作成し destroy まで学ぶ mutating サンプル
    │   └── s3-object-upload/     # 既存 S3 bucket に object を upload する mutating サンプル
    └── gc/
        ├── README.md             # サンプル一覧と共通手順
        ├── project-info/         # Google Cloud 操作ごとの独立した read-only サンプル (project nck-sakurai を読む)
        ├── cloud-run-service-basic/  # Artifact Registry + private Cloud Run service を作る mutating サンプル
        └── adk-agent-engine-basic/   # ADK agent を Vertex AI Agent Engine へ deploy する mutating サンプル
```

冒頭の説明文 `` `packages/`（provider ごとの Terraform サンプル） `` → `` `terraform/`（provider ごとの Terraform サンプル） ``。本文末尾の `packages/<provider>/ 配下の Terraform サンプル` → `terraform/<provider>/ 配下の Terraform サンプル`。

**Step 2: `AGENTS.md` を編集**

パス置換ルール 1-6 を全体に適用。加えて構造を説明する散文を更新:

- TL;DR / Orientation の `packages/<provider>/` 記述 → `terraform/<provider>/`、`each holds only terraform/<operation>/` のような内側階層の言及を削除 (`one <operation>/ per cloud operation` に置換)
- "Add a sample" 手順の `packages/<provider>/terraform/<operation>/` → `terraform/<provider>/<operation>/`、`copy terraform.tf / providers.tf` の親パス記述を追従
- `mise run dev` の解決説明 `packages/ then apps/` → `apps/` (Task 3 整合)
- `Run via the tf task` 例の `-chdir=packages/aws/terraform/<operation>` → `-chdir=terraform/aws/<operation>`、gc の `-chdir=packages/gc/terraform/<operation>` → `-chdir=terraform/gc/<operation>`
- Gotchas の `packages/aws/ and packages/gc/ are Terraform-only` → `terraform/aws/ and terraform/gc/`
- **[review P2] rules ファイル名参照 (L121 付近)**: `.claude/rules/*.md` 一覧の `packages.md` → `projects.md` (Task 4 のリネームに整合)。**`packages/` でなく `packages.md` のため AC3 の `grep "packages/"` では検出されない** — 必ず手動で修正すること。
- **[review P2] Gotchas の内側階層表現 (L103 付近)**: `the same flat terraform/<operation>/ layout` は畳み込み後 `terraform/<provider>/<operation>/` 直置きと食い違う。`packages/aws/terraform/<operation>/ and packages/gc/terraform/<operation>/` のパスを `terraform/aws/<operation>/ and terraform/gc/<operation>/` に直すと同時に、"flat `terraform/<operation>/`" の内側階層を指す言い回しを新構造に合わせて修正。
- **[review P3] bare-word "packages" (L78 付近)**: `provider packages`（path でない英単語）を実態に合わせ `Terraform-only provider samples` 等へ。AC3 grep では拾えないため手動確認。

**Step 3: 移動済み terraform README / cleanup を編集**

`terraform/aws/` と `terraform/gc/` 配下の `README.md` / 各 operation の `README.md` / `cleanup.md` にパス置換ルールを適用 (主に `terraform -chdir=packages/<provider>/terraform/<op>` 形式の例 → `terraform -chdir=terraform/<provider>/<op>`)。`mise run tf <op> <cmd>` 形式の例はパスを含まないため変更不要。

**Step 4: 検証**

```bash
grep -rn "packages/" README.md AGENTS.md terraform/ || echo "[OK] no packages/ refs"
# [review] path でない bare-word "packages" / "packages.md" の取り残しを可視化
grep -rn "packages" README.md AGENTS.md || echo "[OK] no bare packages word"
# symlink 健全性
readlink CLAUDE.md   # -> AGENTS.md であること
```

Expected: `[OK] no packages/ refs`、bare-word grep は L78/L103/L121 を修正後ゼロ、`CLAUDE.md` が `AGENTS.md` を指す。

**Step 5: コミット**

```bash
git add README.md AGENTS.md terraform/
git commit -m "docs: README/AGENTS と terraform サンプル README を新構造へ更新"
```

---

### Task 6: guides / plans / apps の参照更新と最終統合検証

周辺ドキュメントの残存参照を一掃し、リポジトリ全体の整合を検証する。

**Files:**

- Modify: `docs/guides/aws-cli/README.md`, `docs/guides/gcloud-cli/README.md`, `docs/guides/aws-billing/README.md`, `docs/guides/agentcore-runtime-resources/README.md`
- Modify: `docs/plans/` の **歴史的 8件** (下記)。**本マイグレーションの2件 (design / plan) は除外**
- Modify: `apps/openai/README.md`, `apps/cloud-run-rest/README.md`, `apps/agentcore-strands-basic/README.md`, `apps/adk-helloworld/README.md`
- Modify: `apps/adk-helloworld/scripts/package-agent-engine.sh`
- Modify: `.gitignore` ([review P3] L29 の bare-word `Terraform-only provider packages` → `Terraform-only provider samples` 等。任意だが用語整合のため収載)

歴史的 8件 (完全置換 = ユーザー選択):

```text
docs/plans/2026-06-07-sample-terraform-readonly-aws-design.md
docs/plans/2026-06-07-sample-terraform-readonly-aws-plan.md
docs/plans/2026-06-09-aws-terraform-learning-design.md
docs/plans/2026-06-09-gc-terraform-learning-design.md
docs/plans/2026-06-10-aws-agentcore-runtime-design.md
docs/plans/2026-06-10-aws-agentcore-runtime-plan.md
docs/plans/2026-06-11-apps-root-migration-design.md
docs/plans/2026-06-11-apps-root-migration-plan.md
```

**Step 1: 上記ファイルにパス置換ルール 1-6 を適用**

`apps/*/uv.lock` と migration 2件 (design/plan) には触れない。

**Step 2: 最終統合検証 (AC3 マスターゲート)**

```bash
grep -rn "packages/" . \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.terraform \
  --exclude="*.lock" \
  --exclude="2026-06-11-terraform-dir-rename-design.md" \
  --exclude="2026-06-11-terraform-dir-rename-plan.md"
```

Expected: **出力なし** (migration 2件・lock・.terraform を除き `packages/` 参照ゼロ)。何か出たら該当ファイルを修正して再実行。

```bash
# [review] (診断) path でない bare-word "packages" / "packages.md" の取り残しを可視化
grep -rn "packages" . \
  --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.terraform \
  --exclude="*.lock" \
  --exclude="2026-06-11-terraform-dir-rename-design.md" \
  --exclude="2026-06-11-terraform-dir-rename-plan.md" | grep -v "files.pythonhosted.org" || echo "[OK] no stray packages word"
```

Expected: rename を説明する文脈以外で残る場合は用語を修正 (`npm packages` 等の一般語は許容)。

**Step 3: 機能スモークテスト (再確認)**

```bash
mise run tf caller-identity plan   # 新パスで動作
mise run dev openai                # runnable 不変
git log --oneline --follow -1 terraform/gc/project-info/main.tf  # 履歴追跡
```

Expected: いずれも正常。

**Step 4: コミット**

```bash
git add docs/ apps/
git commit -m "docs: guides/plans/apps の packages 参照を terraform/ へ更新"
```

---

## 完了基準 (Acceptance Criteria)

- **AC1 (構造)**: `terraform/{aws,gc}/<operation>/` が並び、`packages/` と内側 `terraform/` が存在しない。
- **AC2 (state 保全)**: 移動後の `terraform.tfstate` 件数が移動前と一致 (=15)。
- **AC3 (参照ゼロ)**: migration 2件・lock・`.terraform/` を除き `grep -rn "packages/"` がゼロ。
- **AC4 (tf タスク)**: `mise run tf caller-identity plan` が新パスで成功。
- **AC5 (runnable 不変)**: `mise run dev openai` / `cost-estimator` が正常終了。
- **AC6 (履歴)**: 移動した `*.tf` で `git log --follow` が追える。
- **AC7 (rules)**: `.claude/rules/projects.md` の glob が `terraform/**` + `apps/**`。

## Non-Goals

- `tf` タスクの provider 汎用化 (gc 対応・引数化)。
- Terraform リモート backend 導入。
- サンプルの追加・削除・内容変更、`apps/` 構造変更。
- migration design/plan 2件の `packages/` 記述の置換 (移行元として保持)。
