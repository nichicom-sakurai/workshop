# Move deployable apps to root-level `apps/` — Implementation Plan

**Goal:** Relocate the three deployable apps from `terraform/<provider>/apps/` to a flat root-level `apps/<app>/`, updating every living reference, in a single PR.

**Architecture:** `git mv` each app to `apps/`, then fix references concern-by-concern (build mechanism → Terraform relative paths → app docs → AI docs → human docs). `bootstrap.sh` is generalized to scan `packages` + `apps`. Historical `docs/plans/2026-06-10-*` and `terraform/aws/cost-estimator/` are untouched.

**Tech Stack:** Bun + TypeScript, Python 3.13 + uv, Terraform, mise task runner. No repo-wide unit-test runner — **verification gates are grep / build / type-check / `terraform validate` / `uv unittest`**, not literal failing unit tests. Each task below uses a "Verify" step in place of the usual TDD "write failing test" step.

**Design Document:** `docs/plans/2026-06-11-apps-root-migration-design.md`

**Recommended Execution:** Loop (HITL) — 8 tasks, moderate complexity, each with a verification gate that benefits from an intervention point.

**Branch:** `feature/apps-root-migration` (no Issue; per repo convention `feature/{kebab-description}`).

**Commit conventions:** `<type>(<scope>): <Japanese subject>`, subject ≤72 chars. Valid types: `feat|fix|docs|style|refactor|perf|test|build|chore|ci|revert`. Scope is free-form.

---

## Target layout

```
apps/
├── agentcore-strands-basic/   (from terraform/aws/apps/)
├── adk-helloworld/            (from terraform/gc/apps/)
└── cloud-run-rest/            (from terraform/gc/apps/)
terraform/
├── aws/   { index.ts, package.json, cost-estimator/, terraform/ }
├── gc/    { index.ts, package.json, terraform/ }
└── openai/
```

## Path-arithmetic reference (apply exactly)

| Location | depth from root | old → new |
| --- | --- | --- |
| Terraform **module** dir `terraform/<p>/<op>/*` | 4 | `../../apps/` → `../../../../apps/` |
| `terraform/gc/README.md` | 3 | `../apps/` → `../../../apps/` |
| from-repo-root command/path strings (any file) | — | `terraform/aws/apps/` and `terraform/gc/apps/` → `apps/` |
| `docs/guides/*/README.md` links | — | `../../../terraform/aws/apps/` → `../../../apps/` |

---

### Task 1: Commit the design + plan documents (intent first)

**Files:**

- Add: `docs/plans/2026-06-11-apps-root-migration-design.md` (already created)
- Add: `docs/plans/2026-06-11-apps-root-migration-plan.md` (this file)

**Step 1: Create the branch**

```bash
git switch -c feature/apps-root-migration
```

**Step 2: Verify the docs exist**

Run: `ls docs/plans/2026-06-11-apps-root-migration-*.md`
Expected: both `-design.md` and `-plan.md` listed.

**Step 3: Commit**

```bash
git add docs/plans/2026-06-11-apps-root-migration-design.md \
  docs/plans/2026-06-11-apps-root-migration-plan.md
git commit -m "docs(plans): apps を root へ移す設計・実装計画を追加"
```

---

### Task 2: `git mv` the three apps to `apps/`

One logical change: relocate the directories. Preserve the real local secret `apps/adk-helloworld/hello_world/.env`; discard stale gitignored env dirs so they regenerate clean.

**Files:**

- Move: `terraform/aws/apps/agentcore-strands-basic/` → `apps/agentcore-strands-basic/`
- Move: `terraform/gc/apps/adk-helloworld/` → `apps/adk-helloworld/`
- Move: `terraform/gc/apps/cloud-run-rest/` → `apps/cloud-run-rest/`

**Step 1: Remove stale gitignored env dirs (they hold absolute paths / are regenerable)**

`.venv` (Python) embeds absolute paths and breaks on move; `node_modules` is reinstalled by bootstrap. `.env` is NOT removed — it must travel with the app.

```bash
rm -rf terraform/aws/apps/agentcore-strands-basic/.venv \
       terraform/aws/apps/agentcore-strands-basic/.build \
       terraform/aws/apps/agentcore-strands-basic/dist \
       terraform/gc/apps/adk-helloworld/.venv \
       terraform/gc/apps/adk-helloworld/.build \
       terraform/gc/apps/cloud-run-rest/node_modules
find terraform/aws/apps terraform/gc/apps -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null || true
find terraform/aws/apps terraform/gc/apps -name .adk -type d -prune -exec rm -rf {} + 2>/dev/null || true
find terraform/aws/apps terraform/gc/apps -name .DS_Store -delete 2>/dev/null || true
```

(`.adk/` is a regenerable local ADK session store; removing it keeps Step 3's "discard stale gitignored state" intent symmetric. `.env` is deliberately NOT removed.)

**Step 2: Move the directories**

```bash
mkdir -p apps
git mv terraform/aws/apps/agentcore-strands-basic apps/agentcore-strands-basic
git mv terraform/gc/apps/adk-helloworld          apps/adk-helloworld
git mv terraform/gc/apps/cloud-run-rest          apps/cloud-run-rest
```

**Step 3: Reconcile leftovers (git mv on a dir does not always carry untracked files like `.env`)**

```bash
# If the source dirs still exist, move any remaining (untracked) files, e.g. hello_world/.env
for src in terraform/aws/apps/agentcore-strands-basic \
           terraform/gc/apps/adk-helloworld \
           terraform/gc/apps/cloud-run-rest; do
  if [ -e "$src" ]; then
    dest="apps/$(basename "$src")"
    cp -a "$src/." "$dest/"   # carry over any untracked leftovers (.env etc.)
    rm -rf "$src"
  fi
done
# Old parent dirs must be gone
rmdir terraform/aws/apps terraform/gc/apps 2>/dev/null || true
```

**Step 4: Verify the move**

```bash
test -d apps/agentcore-strands-basic && test -d apps/adk-helloworld && test -d apps/cloud-run-rest && echo "[OK] moved"
test ! -e terraform/aws/apps && test ! -e terraform/gc/apps && echo "[OK] old gone"
test -f apps/adk-helloworld/hello_world/.env && echo "[OK] .env preserved" || echo "[INFO] no local .env (fine if never created)"
git status --porcelain | grep -E '^R' | head
```
Expected: `[OK] moved`, `[OK] old gone`, and `R` (rename) entries for tracked files.

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(apps): provider 配下の apps を root の apps/ へ移動"
```

---

### Task 3: Generalize the build mechanism (bootstrap, gitignore, vscode)

**Files:**

- Modify: `tools/bootstrap.sh`
- Modify: `.gitignore`
- Modify: `.vscode/settings.json`

**Step 1: `tools/bootstrap.sh` — scan `packages` + `apps`**

Replace the variable declaration:

```bash
# プロジェクト格納ディレクトリ (この配下を全て bootstrap する)
PROJECTS_DIR="packages"
```

with:

```bash
# プロジェクト格納ディレクトリ (この配下を全て bootstrap する)
PROJECTS_DIRS=("packages" "apps")
```

Replace the entire `terraform/*` bootstrap block (from `echo "[INFO] ${PROJECTS_DIR}/* bootstrap: Start"` through its closing `fi`) with:

```bash
echo "[INFO] terraform/* and apps/* bootstrap: Start"
if ! type mise >/dev/null 2>&1; then
  echo "[WARNING] Skip bootstrap because mise could not be found."
else
  for PROJECTS_DIR in "${PROJECTS_DIRS[@]}"; do
    if [ ! -d "$PROJECTS_DIR" ]; then
      echo "[WARNING] Skip: ${PROJECTS_DIR}/ does not exist."
      continue
    fi
    echo "[INFO] ${PROJECTS_DIR}/* bootstrap"
    # 固有 mise.toml / .mise.toml があれば install (root から継承するものは不要)
    find "$PROJECTS_DIR" -name node_modules -prune -o \
      \( -name mise.toml -o -name .mise.toml \) -print |
      while read -r config; do
        dir=$(dirname "$config")
        echo "  -> mise install: ${dir}"
        (cd "$dir" && { mise trust >/dev/null 2>&1 || true; } && mise install)
      done
    # package.json があれば bun install (bun は mise 経由で実行)
    find "$PROJECTS_DIR" -name node_modules -prune -o -name package.json -print |
      while read -r pkg; do
        dir=$(dirname "$pkg")
        echo "  -> bun install: ${dir}"
        (cd "$dir" && mise exec -- bun install)
      done
  done
  echo "[OK] terraform/* and apps/* bootstrap: Success"
fi
```

**Step 2: `.gitignore` — flatten the app patterns**

Replace:

```
# AgentCore direct deployment build artifacts
terraform/aws/apps/*/.build/
terraform/aws/apps/*/dist/
*.zip
```

with:

```
# Deployable app build artifacts (AgentCore ZIP / Agent Engine source archive)
apps/*/.build/
apps/*/dist/
*.zip
```

And delete the now-redundant block:

```
# Agent Engine source archive build artifacts (terraform/gc/apps/*/scripts/package-agent-engine.sh)
terraform/gc/apps/*/.build/
```

**Step 3: `.vscode/settings.json` — update python project paths**

- `"path": "terraform/aws/apps/agentcore-strands-basic"` → `"path": "apps/agentcore-strands-basic"`
- `"path": "terraform/gc/apps/adk-helloworld"` → `"path": "apps/adk-helloworld"`

**Step 4: Verify**

```bash
bash -n tools/bootstrap.sh && echo "[OK] bootstrap syntax"
mise run bs 2>&1 | grep -E "bun install: apps/cloud-run-rest"   # apps now scanned
(cd apps/cloud-run-rest && mise exec -- bunx tsc --noEmit) && echo "[OK] tsc"
git check-ignore apps/agentcore-strands-basic/.build apps/agentcore-strands-basic/dist apps/adk-helloworld/.build && echo "[OK] gitignore"
```
Expected: bootstrap installs `apps/cloud-run-rest`; tsc passes; the three paths are ignored.

**Step 5: Commit**

```bash
git add tools/bootstrap.sh .gitignore .vscode/settings.json
git commit -m "build: bootstrap を packages+apps 走査へ一般化し ignore/vscode を更新"
```

---

### Task 4: Update Terraform relative paths

`terraform validate` does NOT read the artifact (deferred to plan/apply), so the **path-resolution test in Step 5 is the real gate**.

**Files (module dirs, depth 4 → `../../apps` becomes `../../../../apps`):**

- `terraform/aws/agentcore-runtime-basic/`: `terraform.tfvars.template`, `README.md`, `variables.tf`
- `terraform/gc/adk-agent-engine-basic/`: `variables.tf`, `terraform.tfvars.template`, `README.md`, `cleanup.md`
- `terraform/gc/cloud-run-service-basic/`: `README.md`
- `terraform/gc/README.md` (depth 3 → `../apps` becomes `../../../apps`)

**Step 1: AWS `agentcore-runtime-basic`**

- `terraform.tfvars.template`: `../../apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip` → `../../../../apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip`
- `README.md` (line ~18 link): `../../apps/agentcore-strands-basic/` → `../../../../apps/agentcore-strands-basic/`; and the from-root command `terraform/aws/apps/agentcore-strands-basic/scripts/package.sh` → `apps/agentcore-strands-basic/scripts/package.sh`; `terraform/aws/apps/agentcore-strands-basic/dist/...` → `apps/agentcore-strands-basic/dist/...`
- `variables.tf` (description prose): `terraform/aws/apps/agentcore-strands-basic/scripts/package.sh` → `apps/agentcore-strands-basic/scripts/package.sh`

**Step 2: GC `adk-agent-engine-basic`**

- `variables.tf` default: `../../apps/adk-helloworld/.build/source.tar.gz` → `../../../../apps/adk-helloworld/.build/source.tar.gz`
- `terraform.tfvars.template`: same `../../apps/...` → `../../../../apps/...`
- `README.md`: link target `../../apps/adk-helloworld/` → `../../../../apps/adk-helloworld/`; table default `../../apps/adk-helloworld/.build/source.tar.gz` → `../../../../apps/...`; from-root command `bash terraform/gc/apps/adk-helloworld/scripts/package-agent-engine.sh` → `bash apps/adk-helloworld/scripts/package-agent-engine.sh`
- `cleanup.md`: `terraform/gc/apps/adk-helloworld/.build/source.tar.gz` → `apps/adk-helloworld/.build/source.tar.gz`; `bash terraform/gc/apps/adk-helloworld/scripts/...` → `bash apps/adk-helloworld/scripts/...`; `rm -rf terraform/gc/apps/adk-helloworld/.build` → `rm -rf apps/adk-helloworld/.build`

**Step 3: GC `cloud-run-service-basic`**

- `README.md`: link label `[terraform/gc/apps/cloud-run-rest/]` → `[apps/cloud-run-rest/]` with target `../../apps/cloud-run-rest/` → `../../../../apps/cloud-run-rest/`; `(cd terraform/gc/apps/cloud-run-rest && ...)` → `(cd apps/cloud-run-rest && ...)`; `[アプリ側 README](../../apps/cloud-run-rest/README.md)` → `../../../../apps/cloud-run-rest/README.md`

**Step 4: GC `terraform/README.md` (depth 3)**

- `[apps/cloud-run-rest](../apps/cloud-run-rest/)` → `[apps/cloud-run-rest](../../../apps/cloud-run-rest/)`
- `[apps/adk-helloworld](../apps/adk-helloworld/)` (lines ~20 and ~38) → `[apps/adk-helloworld](../../../apps/adk-helloworld/)`

**Step 4b: path-vs-identifier checks (expected: NO edit)**

```bash
grep -n "\.\./\.\./apps\|terraform/.*/apps" terraform/gc/adk-agent-engine-basic/main.tf \
  terraform/gc/cloud-run-service-basic/variables.tf \
  terraform/gc/cloud-run-service-basic/terraform.tfvars.template
```
Expected: no path matches — the `adk-helloworld` / `cloud-run-rest` strings there are identifiers (reasoning-engine `display_name`, Artifact Registry image name), **not** filesystem paths. If a match IS a relative path, apply the same `../../apps` → `../../../../apps` rule; otherwise leave unchanged.

**Step 5: Verify (path resolution is the real gate)**

```bash
test -d terraform/aws/agentcore-runtime-basic/../../../../apps/agentcore-strands-basic && echo "[OK] aws path"
test -d terraform/gc/adk-agent-engine-basic/../../../../apps/adk-helloworld && echo "[OK] adk path"
test -d terraform/gc/cloud-run-service-basic/../../../../apps/cloud-run-rest && echo "[OK] crun path"
# Catch half-applied label+target edits: no un-bumped depth-2 (module) / depth-1 (terraform/README) link
# or var value may remain. These literals are NOT substrings of the corrected ../../../../ and ../../../ forms.
grep -rn -e '"\.\./\.\./apps/' -e '](\.\./\.\./apps/' -e '](\.\./apps/' \
  terraform/aws/terraform terraform/gc/terraform && echo "[NG] un-bumped path" || echo "[OK] no depth-2/1 residual"
for m in terraform/aws/agentcore-runtime-basic \
         terraform/gc/adk-agent-engine-basic \
         terraform/gc/cloud-run-service-basic; do
  mise exec -- terraform -chdir="$m" init -backend=false >/dev/null 2>&1
  mise exec -- terraform -chdir="$m" validate
done
```
Expected: three `[OK] ... path` lines; three `Success! The configuration is valid.`

**Step 6: Commit**

```bash
git add terraform/aws/terraform terraform/gc/terraform
git commit -m "refactor(terraform): app への相対パスを root apps/ へ更新"
```

---

### Task 5: Update app-internal docs / tests / scripts

These are from-repo-root path strings inside the moved apps: replace `terraform/aws/apps/` and `terraform/gc/apps/` with `apps/`.

**Files:**

- `apps/agentcore-strands-basic/README.md`, `apps/agentcore-strands-basic/tests/test_main.py` (docstring)
- `apps/adk-helloworld/README.md`, `apps/adk-helloworld/tests/test_agent.py`, `apps/adk-helloworld/tests/test_agent_engine_packaging.py` (docstrings), `apps/adk-helloworld/scripts/package-agent-engine.sh` (comment line: `terraform/gc/apps/*/.build/` → `apps/*/.build/`)
- `apps/cloud-run-rest/README.md` (path commands + reword the "nested app under `terraform/gc/apps/`" note → "root-level app under `apps/`")

**Step 1: Mechanical path replacement inside the moved apps**

```bash
grep -rln -e "terraform/aws/apps/" -e "terraform/gc/apps/" apps/ \
  | while read -r f; do
      sed -i '' -e 's#terraform/aws/apps/#apps/#g' -e 's#terraform/gc/apps/#apps/#g' "$f"
    done
```

**Step 2: Reword the cloud-run-rest nested-app note**

In `apps/cloud-run-rest/README.md`, change:
`> このアプリは \`terraform/gc/apps/\` 配下の nested app のため \`src/index.ts\` をエントリポイントにしています。`
→
`> このアプリは root の \`apps/\` 配下のアプリのため \`src/index.ts\` をエントリポイントにしています。`

**Step 3: path-vs-identifier check for the AWS package script (expected: NO edit)**

```bash
grep -n "terraform/.*/apps\|\.\./\.\./apps" apps/agentcore-strands-basic/scripts/package.sh
```
Expected: no match — `agentcore-strands-basic.zip` there is an output filename, not a path.

**Step 4: Verify (run the actual suites against the new path)**

```bash
rm -rf apps/agentcore-strands-basic/.venv apps/adk-helloworld/.venv   # force clean uv recreate
mise exec -- uv run --directory apps/agentcore-strands-basic --locked python -m unittest discover -s tests
mise exec -- uv run --directory apps/adk-helloworld --locked python -m unittest discover -s tests
grep -rn -e "terraform/aws/apps" -e "terraform/gc/apps" apps/ && echo "[NG] residual" || echo "[OK] no residual in apps/"
```
Expected: both unittest suites pass (adk includes `test_agent_engine_packaging.py`); `[OK] no residual in apps/`.

**Step 5: Commit**

```bash
git add apps/
git commit -m "docs(apps): app README・テスト・スクリプトの参照を apps/ へ更新"
```

---

### Task 6: Update AI docs (AGENTS.md, .claude/rules)

`CLAUDE.md` is a symlink to `AGENTS.md` — edit `AGENTS.md` only.

**Files:**

- `AGENTS.md`
- `.claude/rules/packages.md`
- `.claude/rules/mise.md`

**Step 1: Mechanical path replacement**

```bash
sed -i '' -e 's#terraform/aws/apps/#apps/#g' -e 's#terraform/gc/apps/#apps/#g' \
  AGENTS.md .claude/rules/packages.md .claude/rules/mise.md
```

**Step 2: Conceptual rewrites in `AGENTS.md`** (paths alone are not enough — the narrative claims provider-nesting)

- §1 Orientation: merge the two app bullets (formerly `terraform/aws/apps/<app>/` and `terraform/gc/apps/<app>/`) into one root-`apps/` bullet, e.g.:
  `- \`apps/<app>/\` — deployable / runnable app code, decoupled from any single provider. Today: \`agentcore-strands-basic\` (Python/uv, AWS AgentCore Runtime ZIP), \`adk-helloworld\` (Python/uv, Google ADK; local run + Agent Engine archive), \`cloud-run-rest\` (Bun, Cloud Run). Not picked up by \`dev:all\` (which loops \`terraform/*\` only); bootstrap scans \`apps/\` too (real \`bun install\` for \`cloud-run-rest\`).`
- Replace any remaining "nested app(s)" / "nested under `terraform/<provider>/apps/`" / "provider-scoped" phrasing with the flat root-`apps/` model.
- Update the `terraform/*` description so it no longer says the provider packages "contain `apps/`".

**Step 3: Conceptual rewrite in `.claude/rules/packages.md`**

- Replace the "Nested apps (`terraform/<name>/apps/<app>/`, e.g. `terraform/gc/apps/cloud-run-rest/`)" sentence with: apps live at root `apps/<app>/`, decoupled from providers; entry point `src/index.ts` (Bun) or package module (Python); not in `dev:all`; bootstrap scans them.
- In "## Python nested apps": drop "provider-scoped" guidance; a new Python app belongs at `apps/<app>/`.

**Step 4: Verify**

```bash
grep -rn -e "terraform/aws/apps" -e "terraform/gc/apps" AGENTS.md .claude/ && echo "[NG] residual path" || echo "[OK] no path residual"
grep -rn -e "provider-scoped" -e "[Nn]ested app" -e "nested under" AGENTS.md .claude/ && echo "[NG] concept residual" || echo "[OK] no concept residual"
test "$(readlink CLAUDE.md)" = "AGENTS.md" && echo "[OK] symlink intact"
```
Expected: `[OK] no path residual`, `[OK] no concept residual`, `[OK] symlink intact`.

**Step 5: Commit**

```bash
git add AGENTS.md .claude/rules/packages.md .claude/rules/mise.md
git commit -m "docs: AGENTS と .claude/rules を root apps/ 構成へ更新"
```

---

### Task 7: Update human docs (README.md, docs/guides)

**Files:**

- `README.md`
- `docs/guides/agentcore-runtime-resources/README.md`
- `docs/guides/aws-billing/README.md`

**Step 1: `README.md` — rewrite the directory tree** (lines ~26–47)

Move the apps out of each provider into a new top-level `apps/` block and adjust the `terraform/` comment:

```text
├── apps/                # デプロイ対象アプリ群 (bootstrap の対象。dev / dev:all の対象外)
│   ├── agentcore-strands-basic/   # AgentCore Runtime に deploy する Python + Strands Agents app
│   ├── adk-helloworld/            # Google ADK の最小 HelloWorld agent (ローカル実行 + Agent Engine deploy 用 source archive 生成)
│   └── cloud-run-rest/            # Cloud Run に deploy する最小の Bun REST service (Dockerfile 付き)
└── terraform/            # プロジェクト群 (bootstrap の対象。dev / dev:all は直下のプロジェクトのみ)
    ├── aws/
    │   ├── cost-estimator/           # 見積もり専用 catalog + bcm-pricing-calculator API adapter
    │   └── terraform/
    │       ├── README.md             # サンプル一覧と共通手順
    │       ├── agentcore-runtime-basic/  # AgentCore Runtime + Strands Agents app を deploy する mutating サンプル
    │       ├── caller-identity/      # AWS 操作ごとの独立した read-only サンプル (caller identity を読む)
    │       ├── s3-private-bucket/    # private S3 bucket を作成し destroy まで学ぶ mutating サンプル
    │       └── s3-object-upload/     # 既存 S3 bucket に object を upload する mutating サンプル
    ├── gc/
    │   └── terraform/
    │       ├── README.md             # サンプル一覧と共通手順
    │       ├── project-info/         # Google Cloud 操作ごとの独立した read-only サンプル (project nck-sakurai を読む)
    │       ├── cloud-run-service-basic/  # Artifact Registry + private Cloud Run service を作る mutating サンプル
    │       └── adk-agent-engine-basic/   # ADK agent を Vertex AI Agent Engine へ deploy する mutating サンプル
    └── openai/              # OpenAI Agents SDK (TypeScript) の最小 HelloWorld サンプル (Agent + run、key 未設定時は案内して exit 0)
```

(Note: `apps/` sorts before `tools/`? Keep the existing top-level order readable — place `apps/` after `tools/` and before `terraform/` as shown. The `└──`/`├──` glyphs must stay consistent: `apps/` uses `├──`, `terraform/` is the last top-level entry with `└──`.)

**Step 2: `docs/guides/*/README.md` — fix relative links**

```bash
sed -i '' -e 's#\.\./\.\./\.\./terraform/aws/apps/#../../../apps/#g' \
  -e 's#terraform/aws/apps/#apps/#g' \
  docs/guides/agentcore-runtime-resources/README.md docs/guides/aws-billing/README.md
```

**Step 3: Verify (full repo residual sweep, excluding planning docs)**

```bash
grep -rn --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.git --exclude-dir=.terraform \
  -e "terraform/aws/apps" -e "terraform/gc/apps" . | grep -v "docs/plans/" && echo "[NG] residual" || echo "[OK] clean"
```
Expected: `[OK] clean` (only `docs/plans/*` describe the before→after, intentionally).

**Step 4: Commit**

```bash
git add README.md docs/guides/
git commit -m "docs: README とガイドを root apps/ 構成へ更新"
```

---

### Task 8: Full acceptance verification

No new commit (verification only); fix-up commits if any gate fails.

**Step 1: Run every acceptance gate**

```bash
# AC1 move complete
find apps -maxdepth 1 -type d
test ! -e terraform/aws/apps && test ! -e terraform/gc/apps && echo "[OK] AC1"

# AC2 no residual paths (exclude planning docs)
grep -rn --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.git --exclude-dir=.terraform \
  -e "terraform/aws/apps" -e "terraform/gc/apps" . | grep -v "docs/plans/" || echo "[OK] AC2 paths"

# AC2b no residual concepts (AGENTS.md:12 uses lowercase "nested" — must include [Nn]ested app)
grep -rn --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=.git \
  -e "provider-scoped" -e "[Nn]ested app" -e "nested under" AGENTS.md .claude/ || echo "[OK] AC2 concepts"

# AC3 bootstrap installs apps deps
mise run bs 2>&1 | grep -E "bun install: apps/cloud-run-rest" && echo "[OK] AC3"

# AC4 tsc
(cd apps/cloud-run-rest && mise exec -- bunx tsc --noEmit) && echo "[OK] AC4"

# AC5 python suites
mise exec -- uv run --directory apps/agentcore-strands-basic --locked python -m unittest discover -s tests
mise exec -- uv run --directory apps/adk-helloworld --locked python -m unittest discover -s tests && echo "[OK] AC5"

# AC6 terraform validate (+ path resolution)
for m in terraform/aws/agentcore-runtime-basic \
         terraform/gc/adk-agent-engine-basic \
         terraform/gc/cloud-run-service-basic; do
  mise exec -- terraform -chdir="$m" init -backend=false >/dev/null 2>&1
  mise exec -- terraform -chdir="$m" validate
done
echo "[OK] AC6"
```

**Step 2: Operational note to surface in the PR description**

Live local Terraform state may carry the old `../../apps/...` artifact path in a gitignored `terraform.tfvars`. Before the next `plan`/`apply`, update local `terraform.tfvars` to the new `../../../../apps/...` path (or copy from the updated `terraform.tfvars.template`). `destroy` of existing AgentCore / Agent Engine resources does not need the artifact path.

**Step 3: Confirm no unintended changes**

```bash
git status --porcelain
git log --oneline feature/apps-root-migration ^main
```
Expected: clean tree; 7 commits (Tasks 1–7). `terraform/aws/cost-estimator/` and `docs/plans/2026-06-10-*` untouched.

---

## Non-Goals (do not do)

- Rename apps or change any package `name`.
- Add mise tasks, an `apps/README.md`, or new tooling.
- Touch `terraform/aws/cost-estimator/`.
- Rewrite historical `docs/plans/2026-06-10-*`.
- Edit `mise.toml` (no app references; `dev`/`dev:all`/`tf` target `terraform/*` only — confirmed).

## Verification Gate Summary

| Gate | Command | Expected |
| --- | --- | --- |
| Residual paths | `grep -rn ... \| grep -v docs/plans/` | empty |
| Residual concepts | `grep -rn -e provider-scoped -e "nested under" AGENTS.md .claude/` | empty |
| Bootstrap | `mise run bs` | installs `apps/cloud-run-rest`, exit 0 |
| Type-check | `bunx tsc --noEmit` in `apps/cloud-run-rest` | pass |
| Python ×2 | `uv run --directory apps/<app> --locked python -m unittest discover -s tests` | pass |
| Terraform ×3 | `test -d .../../../../apps/<app>` + `terraform validate` | dir exists + valid |
