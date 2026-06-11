# Move deployable apps to a root-level `apps/` directory

Date: 2026-06-11
Issue URL: none

## Context

`workshop` is a cloud / IaC learning monorepo. Today, deployable app code that
backs the Terraform learning samples lives **nested under each provider package**:

- `terraform/aws/apps/agentcore-strands-basic/` — Python / uv, AgentCore Runtime ZIP artifact.
- `terraform/gc/apps/cloud-run-rest/` — Bun REST service, Cloud Run image.
- `terraform/gc/apps/adk-helloworld/` — Python / uv, Agent Engine inline-source archive.

This nesting encodes a **provider-scoped ownership model** (an app belongs to one
cloud provider), stated explicitly in `AGENTS.md` and `.claude/rules/packages.md`
("Keep them self-contained and provider-scoped").

The selected direction is to **drop that provider coupling** and relocate all
deployable apps to a single **flat, root-level `apps/`** directory, making `apps/`
a first-class top-level concept alongside `terraform/` (the established
Turborepo / Nx style `apps/` + `terraform/` split). The directory-level ownership
link to a provider is removed; the *functional* dependency (a provider Terraform
module reads its app's build artifact) is inherent and remains, expressed via a
longer relative path.

Target layout:

```
apps/
├── agentcore-strands-basic/   (from terraform/aws/apps/)
├── cloud-run-rest/            (from terraform/gc/apps/)
└── adk-helloworld/            (from terraform/gc/apps/)
terraform/
├── aws/   { index.ts, package.json, terraform/, cost-estimator/ }
├── gc/    { index.ts, package.json, terraform/ }
└── openai/
```

Confirmed decisions (from brainstorming):

- Motivation: remove the provider ↔ app organizational coupling.
- Layout under `apps/`: **flat** (`apps/<app>/`), not provider-grouped.
- Execution: **single PR, full migration** (approach A1) — atomic, no
  intermediate inconsistency.
- **No app renames** — existing names are self-describing; renaming is YAGNI.
- Historical plan/design docs under `docs/plans/2026-06-10-*` are **point-in-time
  records and stay unchanged** (no revisionist rewrite).

Key facts established during exploration:

- `tools/bootstrap.sh` hardcodes `PROJECTS_DIR="packages"` and recursively
  `find`s for `mise.toml` / `package.json`. After the move it must also scan
  `apps/`, otherwise `cloud-run-rest`'s `bun install` (its `@types/bun` dev dep)
  no longer runs at bootstrap.
- Both provider Terraform modules reference their app via a **relative path**
  (`../../apps/...`) resolved from the module dir. A root-level `apps/` is 4
  levels up from each module dir, so the path becomes `../../../../apps/...`.
- `mise.toml` has **no** app references (`dev:all` / `dev` / `chat` / `web` target
  `terraform/*` top-level only; `tf` targets `terraform/aws/`). No
  `mise.toml` change is required.
- `.codex/` has no app references.
- Live **local** Terraform state exists (`agentcore-runtime-basic/`
  `terraform.tfstate.backup` + `terraform.tfvars`). These are gitignored, so they
  are not part of the PR, but the user must update their own local
  `terraform.tfvars` path after the move.
- Hits on `pyproject.toml` / `uv.lock` / `package.json` / `bun.lock` /
  `src/index.ts` are the package's **own name** (`name = "..."`), not path
  references — unchanged by a directory move.

## Boundaries

**Never**

- Rewrite historical plan/design docs (`docs/plans/2026-06-10-*`) to the new path.
- Rename any app directory or change any package's `name` field.
- Touch `terraform/aws/cost-estimator/` (not an app; out of scope).
- Commit gitignored local state (`terraform.tfvars`, `terraform.tfstate*`).
- Hardcode versions or secrets while editing.

**Always**

- Update every *living* reference in the same change (build mechanism, Terraform
  paths, configs, docs) — repo "change consistency" rule.
- Use `git mv` so history follows the files.
- Generalize `bootstrap.sh` discovery (scan `packages` + `apps`) rather than
  bolt on a second hardcoded block — root-cause fix.
- Keep half-width space between latin and Japanese in any Japanese doc edits.

**Ask First**

- Any scope beyond the move (new mise tasks for `apps/`, an `apps/README.md`,
  app renames) — these were explicitly deferred (YAGNI).

## Architecture / file-change list

### 1. Directory moves (`git mv`)

- `terraform/aws/apps/agentcore-strands-basic/` → `apps/agentcore-strands-basic/`
- `terraform/gc/apps/cloud-run-rest/` → `apps/cloud-run-rest/`
- `terraform/gc/apps/adk-helloworld/` → `apps/adk-helloworld/`
- Resulting empty `terraform/aws/apps/` and `terraform/gc/apps/` disappear (git
  does not track empty dirs).

### 2. Build mechanism

- `tools/bootstrap.sh` — generalize the package scan to iterate over
  `("packages" "apps")` (skip a dir that does not exist). Preserves
  auto-discovery; restores `bun install` for `cloud-run-rest`.
- `.gitignore` — replace the provider-specific patterns with flat ones:
  - `terraform/aws/apps/*/.build/` + `terraform/gc/apps/*/.build/` → `apps/*/.build/`
  - `terraform/aws/apps/*/dist/` → `apps/*/dist/`
  - update the accompanying comments.
- `.vscode/settings.json` — `python-envs.pythonProjects` paths:
  - `terraform/aws/apps/agentcore-strands-basic` → `apps/agentcore-strands-basic`
  - `terraform/gc/apps/adk-helloworld` → `apps/adk-helloworld`

### 3. Terraform relative paths (`../../apps/` → `../../../../apps/`)

- AWS `terraform/aws/agentcore-runtime-basic/`:
  `variables.tf` (description), `terraform.tfvars.template`, `README.md`.
- GC `terraform/gc/adk-agent-engine-basic/`:
  `variables.tf` (`default`), `terraform.tfvars.template`, `README.md`,
  `cleanup.md`, and `main.tf` **iff** it holds a path (verify: may be a
  `display_name` identifier, not a path → then no edit).
- GC `terraform/gc/cloud-run-service-basic/`:
  `README.md` path commands (`cd terraform/gc/apps/cloud-run-rest`,
  `../../apps/cloud-run-rest/` links); `variables.tf` /
  `terraform.tfvars.template` **only if** they hold a path (verify: likely the
  Artifact Registry image identifier `cloud-run-rest`, not a path → then no edit).
- GC `terraform/gc/README.md` — `../apps/...` index links →
  `../../apps/...`.

### 4. App-internal docs / tests / scripts

- `apps/agentcore-strands-basic/README.md`, `tests/test_main.py` (docstring
  `--directory terraform/aws/apps/...` → `--directory apps/...`),
  `scripts/package.sh` (verify: `agentcore-strands-basic.zip` is an output
  filename, not a path → likely no edit).
- `apps/adk-helloworld/README.md`, `tests/test_agent.py`,
  `tests/test_agent_engine_packaging.py` (docstrings), `scripts/package-agent-engine.sh`
  (comment referencing the gitignore path `terraform/gc/apps/*/.build/`).
- `apps/cloud-run-rest/README.md` (`cd terraform/gc/apps/cloud-run-rest` →
  `cd apps/cloud-run-rest`; the "nested app under `terraform/gc/apps/`" note →
  reword to "root-level app under `apps/`").

### 5. AI / human docs

- `AGENTS.md` — rewrite the structural narrative: apps are no longer "nested
  under `terraform/<provider>/apps/`" and no longer "provider-scoped"; they live
  flat under root `apps/`. Update every path string (TL;DR, Orientation, Verify,
  Gotchas). This is the largest single doc change.
- `.claude/rules/packages.md` — replace the "Nested apps
  (`terraform/<name>/apps/<app>/`)" and "provider-scoped" language with the flat
  `apps/<app>/` model; update the Python-apps section.
- `.claude/rules/mise.md` — `terraform/gc/apps/cloud-run-rest/Dockerfile` →
  `apps/cloud-run-rest/Dockerfile`.
- `README.md` (top-level, Japanese) — the structure tree at lines 28–40 (apps
  under each provider) → a root `apps/` block; keep half-width spacing rules.
- `docs/guides/agentcore-runtime-resources/README.md` and
  `docs/guides/aws-billing/README.md` — relative links
  `../../../terraform/aws/apps/agentcore-strands-basic/...` →
  `../../../apps/agentcore-strands-basic/...` (recompute depth per file).

### Estimated blast radius

~20 living files edited + 3 directory moves. Historical `docs/plans/2026-06-10-*`
and the `cost-estimator` module are untouched.

## Acceptance Criteria (Given-When-Then)

1. **Move complete**
   - Given the repo after the change,
   - When `find apps -maxdepth 1 -type d` is run,
   - Then `apps/agentcore-strands-basic`, `apps/cloud-run-rest`, and
     `apps/adk-helloworld` exist, and `terraform/aws/apps` /
     `terraform/gc/apps` no longer exist.

2. **No residual references (paths)**
   - Given the change,
   - When `grep -rn --exclude-dir=node_modules --exclude-dir=.venv
     --exclude-dir=.git -e "terraform/aws/apps" -e "terraform/gc/apps" .` is run,
   - Then only historical files under `docs/plans/2026-06-10-*` (and gitignored
     local `.terraform`/state) match — zero living references remain.

2b. **No residual references (concepts)**
   - Given the change,
   - When the AI/human docs are grepped for the old conceptual phrasing
     (`-e "provider-scoped" -e "[Nn]ested app" -e "nested under"` — `AGENTS.md`
     uses lowercase "nested"),
   - Then `AGENTS.md` and `.claude/rules/packages.md` no longer describe apps as
     provider-scoped or nested under a provider package (only intentional history
     under `docs/plans/2026-06-10-*` may remain).

3. **Bootstrap installs app deps**
   - Given a clean checkout,
   - When `mise run bs` runs,
   - Then it reports `bun install` for `apps/cloud-run-rest`, and exits 0.

4. **TypeScript app still type-checks**
   - Given `apps/cloud-run-rest`,
   - When `mise exec -- bunx tsc --noEmit` runs from that dir,
   - Then it passes with no errors.

5. **Python apps still verify**
   - Given `apps/agentcore-strands-basic` and `apps/adk-helloworld`,
   - When `mise exec -- uv run --directory apps/<app> --locked python -m unittest
     discover -s tests` runs for each,
   - Then both suites pass (including `test_agent_engine_packaging.py`).

6. **Terraform still validates**
   - Given the affected modules
     (`agentcore-runtime-basic`, `adk-agent-engine-basic`,
     `cloud-run-service-basic`),
   - When `mise exec -- terraform -chdir=<module> validate` runs (init as needed),
   - Then each validates, and the updated relative paths resolve to the new
     `apps/<app>/` locations.

7. **Docs are internally consistent**
   - Given the edited Markdown,
   - When relative links in changed READMEs/guides are followed,
   - Then each resolves to an existing target (no broken links).

## Decisions Made

| Decision | Rationale | Confidence |
| --- | --- | --- |
| Flat `apps/<app>/`, not `apps/<provider>/<app>/` | User goal is to remove provider coupling; current app names are unique and self-describing | user-selected |
| Single PR (A1) over phased (A3) | Repo "change consistency" rule; avoids a doc-inconsistent intermediate state in a learning repo | 85% |
| Generalize `bootstrap.sh` to scan `packages`+`apps` | Root-cause fix vs. a second hardcoded block; keeps auto-discovery | 90% |
| Leave historical `docs/plans/2026-06-10-*` unchanged | They are point-in-time records; rewriting them is revisionist | 90% |
| No app renames, no new `apps/` tooling | YAGNI; not part of the stated motivation | 85% |
| Terraform path `../../apps/` → `../../../../apps/` | Deterministic: module dir is 4 levels below repo root | 90% |

## Open Questions

- Three name-grep hits need a path-vs-identifier check at implementation time
  (resolve inline, no user input expected):
  `gc/adk-agent-engine-basic/main.tf`, `gc/cloud-run-service-basic/variables.tf`
  + `terraform.tfvars.template`, `aws/.../scripts/package.sh`. If they are
  identifiers (display_name / image name / zip filename), they are left unedited.

## Non-Goals

- Renaming apps or changing any package `name`.
- Adding mise tasks, a root `apps/README.md`, or any new tooling surface.
- Moving or changing `terraform/aws/cost-estimator/`.
- Rewriting historical plan/design docs.
- Re-applying or migrating live Terraform state. (Operational note: the user
  updates their own gitignored `terraform.tfvars` path after the move; `destroy`
  of existing AgentCore / Agent Engine resources does not require the artifact
  path, but a future `plan`/`apply` does.)
