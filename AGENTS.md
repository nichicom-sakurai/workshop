# AGENTS.md

AI-agent guide for the `workshop` monorepo. For human-facing detail, see [README.md](./README.md) (Japanese).

> This file is the real target of the `CLAUDE.md` symlink (`CLAUDE.md` -> `AGENTS.md`).
> Claude Code reads it as `CLAUDE.md`, Codex reads it as `AGENTS.md`, and the content is identical — **editing this file updates both**. Edit `AGENTS.md`, never `CLAUDE.md` directly (writing the symlink path would break the link).
> This doc is in English per the global "AI docs in English" convention; `README.md` stays Japanese for human contributors.

## TL;DR (read first)

- **Cloud / IaC learning monorepo.** Independent projects live in `packages/<name>/`. Tool versions are centrally pinned by [mise](https://mise.jdx.dev/) in `mise.toml`.
- **Learning skeleton + Terraform samples.** Each of `packages/aws/` and `packages/gc/` keeps its `package.json` + `index.ts` skeleton (`console.log("Hello from <name>")`) and adds self-contained Terraform samples under `packages/<provider>/terraform/<operation>/`. AWS starts with `caller-identity` (read-only), `s3-private-bucket` (mutating), and `s3-object-upload` (mutating); Google Cloud starts with `project-info`, expands through storage learning samples, and adds a Cloud Run deploy sample (`cloud-run-service-basic`) backed by a nested app under `packages/gc/apps/`. Beyond Terraform, AWS also ships `packages/aws/cost-estimator/` — a non-Terraform, estimation-only YAML catalog (web/database/container/functions/iam) plus a `bcm-pricing-calculator` API adapter, zero **runtime** deps (`@types/bun` dev-only; YAML via `Bun.YAML`, tests via `bun:test`).
- **[WARNING] no repo-wide test / lint / typecheck.** `packages/gc/apps/cloud-run-rest/` and `packages/aws/cost-estimator/` each carry a `tsconfig.json` (+ `@types/bun`) for `bunx tsc --noEmit` (and `cost-estimator` adds `bun test`); everything else runs untyped on Bun. Terraform exists as learning samples with local state only; no remote backend is configured. See "Gotchas".
- Drive everything through mise tasks (`mise run ...`). A bare `bun` is not on PATH, but the tasks wrap it (`mise exec -- bun`), so `mise run` works as-is.

## 1. Orientation (layout)

- `mise.toml` — tool versions (`[tools]`) + task definitions (`[tasks.*]`). **The single source of version truth.**
- `tools/bootstrap.sh` — idempotent full setup (`set -euo pipefail`); skips gracefully when mise is absent.
- `tools/git-hooks/commit-msg` — dependency-free bash validator for Conventional Commits (`<type>(<scope>): ...`, fixed type enum, 72-char subject; merge/autosquash skipped). Enabled via `core.hooksPath` by `mise run install-hooks` / `bs`. **scope is free-form, not enum-checked** (keeps the auto-discover model — no per-package config edits).
- `packages/*` — the projects. Targets of `bun install` / `dev` / `dev:all`. Each is independent (no root npm workspaces). Currently `aws` and `gc`; each contains `terraform/<operation>/` — one independent Terraform root module per cloud operation. AWS includes `caller-identity` (read-only), `s3-private-bucket` (mutating), and `s3-object-upload` (mutating); Google Cloud includes `project-info`, storage learning samples, and `cloud-run-service-basic` (mutating, deploys the nested app below).
- `packages/gc/apps/<app>/` — deployable app code used by Terraform samples (first: `cloud-run-rest`, a Bun REST service — zero **runtime** deps, with `@types/bun` as a dev-only type dependency — plus a Dockerfile for Cloud Run). Nested apps use `src/index.ts` as the entry point and are **not** picked up by `dev:all` (its loop covers `packages/*/` only; `dev <name>` is documented for top-level packages); bootstrap's recursive `find` still runs `bun install` in them (a real install for `cloud-run-rest`, fetching `@types/bun`; a no-op for dependency-free apps).
- `packages/aws/cost-estimator/` — a nested, non-Terraform module (sibling of `packages/aws/terraform/`): estimation-only YAML catalog under `catalog/<category>.yaml` (loader globs `catalog/*.yaml`), `src/` adapter that converts the catalog into `bcm-pricing-calculator` `BatchCreateWorkloadEstimateUsage` usage entries (each labeled `mapping_status` = `mapped`/`schema_only`/`needs_research`), and a `--submit` wrapper that shells out to the AWS CLI. Entry point `index.ts`; not picked up by `dev:all` (nested); `bun install` runs in it during bootstrap. `usageAccountId` and AWS creds are never stored — resolved from `--account-id`/`AWS_ESTIMATE_ACCOUNT_ID`/a `000000000000` placeholder and standard AWS auth. See [`packages/aws/cost-estimator/README.md`](./packages/aws/cost-estimator/README.md).
- `.claude/` and `.codex/` — agent tooling for this repo; see §8.

## 2. Run

mise tasks execute inside mise's resolved environment, so they are copy-paste safe.

| Purpose | Command | Notes |
| --- | --- | --- |
| Full setup | `mise run bs` | alias of `bootstrap`; breakdown below |
| Enable commit hook | `mise run install-hooks` | sets `core.hooksPath=tools/git-hooks` (also run by `bs`) |
| Run one project | `mise run dev <name>` | `<name>` is `aws` / `gc` |
| Run all projects | `mise run dev:all` | loops over `packages/` |
| List tasks | `mise tasks` | shows registered tasks |

`mise run bs` (`tools/bootstrap.sh`) does:

1. `mise install` at root (after `mise trust`; skipped if mise is missing).
2. Scans `packages/*`; runs `mise install` **only in dirs that have their own `mise.toml` / `.mise.toml`** (the rest inherit root config).
3. Runs `mise exec -- bun install` in every dir that has a `package.json`.

> [WARNING] A bare `bun` is **not on the shell PATH** (mise-managed, shell not activated). Typing `bun ...` directly returns `command not found` (exit 127).
> - `mise run dev` / `dev:all` work regardless — their task definitions call `mise exec -- bun`.
> - For a manual bun, prefix `mise exec -- ` (e.g. `mise exec -- bun run start`, `mise exec -- bun --version`).
> - For interactive use, activate the shell: `eval "$(mise activate zsh)"`. See README's "shell への activate（推奨）".

## 3. Change

Add a project (reference: `packages/gc/`) — or run the `/new-package <name>` skill:

1. Create `packages/<name>/`.
2. Add `package.json`: `"private": true`, `"type": "module"`, `"scripts": { "start": "bun run index.ts" }`.
3. Add `index.ts` (entry point).
4. Only if the project needs a different tool/version, add a `mise.toml` (or hidden `.mise.toml`; bootstrap detects both) and run `mise trust` before use (it merges over root).

`dev:all` and bootstrap auto-discover packages via `find`, so **no task edits are needed** when adding one.

Terraform learning samples:

- `packages/aws/terraform/<operation>/` — each AWS operation is a self-contained, independent root module (own state) placed directly under `terraform/`. Current samples include `caller-identity` (read-only, uses `data "aws_caller_identity" "current" {}` only), `s3-private-bucket` (mutating, creates a private S3 bucket and public access block), and `s3-object-upload` (mutating, uploads a local file to an existing S3 bucket).
  - Run via the `tf` task: `mise run tf <operation> <command>` (e.g. `mise run tf caller-identity plan`), or directly `mise exec -- terraform -chdir=packages/aws/terraform/<operation> ...`.
  - Add one: create `<operation>/` under `terraform/` (copy `terraform.tf` / `providers.tf` so it stays self-contained), then add a row to `packages/aws/terraform/README.md` (the shared-workflow index).
- `packages/gc/terraform/<operation>/` — each Google Cloud operation is a self-contained, independent root module (own state) placed directly under `terraform/`. First sample: `project-info`, which reads `data "google_project" "current"` with a `postcondition` asserting the project number for `nck-sakurai`. API enablement is factored into dedicated `*-api-enable` samples (`storage-api-enable` for one API; `cloud-run-api-enable` enables the `run` / `artifactregistry` / `cloudbuild` trio via `google_project_service` with `for_each`), each `disable_on_destroy = false` so cleanup never turns an API off. `cloud-run-service-basic` (mutating) creates an Artifact Registry repository + a private Cloud Run v2 service (its prerequisite APIs come from `cloud-run-api-enable`, applied first); the container image is built/pushed via `gcloud builds submit` (not Terraform), so its README documents a two-stage apply (`-target` the repository first).
  - Not covered by the `tf` task (which targets AWS samples); run directly with `mise exec -- terraform -chdir=packages/gc/terraform/<operation> ...`.
  - Add one: create `<operation>/` under `terraform/` (copy `terraform.tf` / `providers.tf` so it stays self-contained), then add a row to `packages/gc/terraform/README.md` (the shared-workflow index).
- read-only samples do not create, update, or destroy resources. mutating samples are marked in each Terraform README and must document cleanup / `destroy`. Credentials come from each provider's standard mechanism (AWS env / profile; Google ADC) — never hardcoded.

## 4. Verify

> No test runner / typechecker is configured, so verification today means "run it and check the output."

- After a change: `mise run dev <name>` exits cleanly and prints `Hello from <name>`.
- Integration: `mise run dev:all` runs all projects (aws / gc) without crashing.
- Version pinning: `mise current` matches `mise.toml` `[tools]`.
- Environment problems: delegate to the `env-doctor` agent (mise / bun / trust / run / git checks).
- `packages/gc/apps/cloud-run-rest/` has a `tsconfig.json` + `@types/bun`, so `mise exec -- bunx tsc --noEmit` (run from that dir) typechecks it today. No repo-wide typecheck task is wired into `mise.toml` yet.
- [Recommended · not set up yet] a repo-wide typecheck / lint / test / formatter is still **undecided**. If you add one (e.g. `bun test` with `*.test.ts`, or a root `tsc --noEmit`), wire it into `packages/*/package.json` scripts, `mise.toml` tasks, and this doc **together**. **This is a recommendation, not a command that works today.**

Note: skeleton packages have no dependencies, so `bun install` creates no `node_modules/` — its absence is not an error.

## 5. Conventions (internalize before acting)

- [OK] Pin exact tool versions in `mise.toml`. [NG] `latest` / `any`, or hardcoding version numbers in docs/scripts. Check with `mise current`.
- [OK] Versions live **only** in `mise.toml` — this doc never spells out a version number. Exception: a `Dockerfile` base image can't read `mise.toml`, so it pins the same version explicitly (e.g. `packages/gc/apps/cloud-run-rest/Dockerfile` ↔ `[tools]` `bun`) — update both together.
- [OK] `mise trust` any new `mise.toml` / `.mise.toml` before use (bootstrap auto-trusts; do it yourself for manually created ones).
- [OK] Shell scripts: `set -euo pipefail`, quote every variable (`"${var}"`), status via `[OK]` / `[NG]` / `[WARNING]` / `[INFO]` markers, no decorative emoji.
- [OK] Secrets: never hardcode. Templates use a `.template` suffix; machine-specific values go in `.local` files or env vars.
- [OK] Consistency: when you change config / CLI flags / docs / CI / code, update all related places together.
- [OK] Text style for any Japanese (e.g. README): half-width space between latin and Japanese (`Flutter アプリ`), no space between a number and Japanese (`3個`, `2025年`).
- Link, don't copy: point to [README.md](./README.md) for human setup detail instead of duplicating it.

## 6. Gotchas

- **git is initialized.** Branches / commits / PRs apply. Follow the global conventions: branch `{prefix}/GH-{issue}` when an issue exists, otherwise `{prefix}/{kebab-case-description}`; commit `{type}({scope}): {Japanese description}`.
- **`bun: command not found` (exit 127).** Shell not activated — use `mise exec -- bun ...` or `eval "$(mise activate zsh)"`. Does not affect `mise run dev` / `dev:all`.
- **Terraform samples include read-only and mutating examples.** `packages/aws/terraform/<operation>/` and `packages/gc/terraform/<operation>/` hold one independent root module per cloud operation. Mutating samples follow the same flat `terraform/<operation>/` layout — distinguished by the README's 種別 column, not a separate tree — and must include cleanup / `destroy` guidance. No remote backend is configured, and bootstrap does no provisioning.
- **Lockfile / tsconfig: skeleton packages have neither; `cloud-run-rest` has both.** Skeleton packages have no deps (no `bun.lock`) and bun runs TypeScript / ESM natively without a `tsconfig.json`, so `index.ts` runs directly with no typecheck step. The exception is `packages/gc/apps/cloud-run-rest/`: it carries `@types/bun`, a committed `bun.lock` (repeatable installs, like Terraform's committed `.terraform.lock.hcl`), and a `tsconfig.json` enabling `bunx tsc --noEmit`. Don't assume a repo-wide typecheck exists.

## 7. Troubleshooting (symptom -> fix)

- `bun: command not found` -> shell not activated. Prefix `mise exec -- bun ...`, or run `eval "$(mise activate zsh)"`.
- `mise install` / `mise run` asks to trust -> run `mise trust` (a new or changed `mise.toml` was detected).
- `mise run dev <name>` does nothing -> check `packages/<name>/` exists, `package.json` has `scripts.start`, and `mise run bs` has run.
- `mise: command not found` -> mise is not installed. See <https://mise.jdx.dev/getting-started.html>.

## 8. Agent tooling (.claude / .codex)

Project-scoped config for the coding agents. Both Claude Code and Codex are wired up; they share the same skill, kept in sync across the two trees.

Claude Code (`.claude/`, auto-loaded):

- `.claude/agents/env-doctor.md` — subagent that diagnoses the toolchain / bootstrap state.
- `.claude/skills/new-package/` — `/new-package <name>` slash command to scaffold a project.
- `.claude/rules/*.md` — path-scoped conventions, auto-loaded when editing matching files: `packages.md`, `shell.md`, `mise.md`.

Codex (`.codex/`, loaded for trusted projects):

- `.codex/skills/new-package/SKILL.md` — the Codex twin of the Claude `new-package` skill (verified to surface in Codex's "Available skills"). Keep the two `new-package/SKILL.md` files in sync.
- `.codex/hooks.json` — a live `session_start` hook printing a one-line repo reminder. Codex asks you to approve the hook (trusted hash) on first run. Schema/details in `.codex/hooks/README.md`.
- `.codex/config.toml` — Codex project config (options commented out by default).
- `.codex/rules/` — empty: the Codex permission-rules feature (`request_rule`) is removed in the installed CLI; see its `README.md`.
- **Project instructions for Codex live in this `AGENTS.md`** (merged git-root → cwd), not under `.codex/`. Note: this repo is not yet in Codex's trusted-projects list, so trust it in Codex for `.codex/` to take full effect.
