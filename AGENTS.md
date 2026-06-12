# AGENTS.md

AI-agent guide for the `workshop` monorepo. For human-facing detail, see [README.md](./README.md) (Japanese).

> This file is the real target of the `CLAUDE.md` symlink (`CLAUDE.md` -> `AGENTS.md`).
> Claude Code reads it as `CLAUDE.md`, Codex reads it as `AGENTS.md`, and the content is identical — **editing this file updates both**. Edit `AGENTS.md`, never `CLAUDE.md` directly (writing the symlink path would break the link).
> This doc is in English per the global "AI docs in English" convention; `README.md` stays Japanese for human contributors.

## TL;DR (read first)

- **Cloud / IaC learning monorepo.** Provider Terraform-sample roots live in `terraform/<provider>/`; runnable / deployable apps live in `apps/<app>/`. Tool versions are centrally pinned by [mise](https://mise.jdx.dev/) in `mise.toml`.
- **Provider Terraform samples.** `terraform/aws/` and `terraform/gc/` are provider Terraform-sample roots — each holds one `<operation>/` per cloud operation (self-contained root modules; no runnable Bun entry point). AWS starts with `caller-identity` (read-only), `s3-private-bucket` (mutating), `s3-object-upload` (mutating), `agentcore-runtime-basic` (mutating, backed by a Python app under `apps/`), and `agentcore-rag-chat` (mutating, a supervisor + 3 specialist RAG-agent chat backed by a Python app under `apps/`, using 3 Bedrock Knowledge Bases on S3 Vectors + AgentCore Memory); Google Cloud starts with `project-info`, expands through storage learning samples, and adds Cloud Run (`cloud-run-service-basic`) and Vertex AI Agent Engine (`adk-agent-engine-basic`, prerequisite API via `vertex-ai-api-enable`) deploy samples backed by apps under `apps/` (which also holds `adk-helloworld`, a Google ADK HelloWorld Python app run locally via `adk run` / `adk web` that also generates the inline-source archive deployed by `adk-agent-engine-basic`). Beyond Terraform, the AWS cost-estimation tool lives at `apps/cost-estimator/` (a runnable app, no longer under the `aws` package) — a non-Terraform, estimation-only YAML catalog (web/database/container/functions/iam) plus a `bcm-pricing-calculator` API adapter, zero **runtime** deps (`@types/bun` dev-only; YAML via `Bun.YAML`, tests via `bun:test`).
- **OpenAI Agents SDK sample.** `apps/openai/` is the one **runnable** app under `apps/` (it backs no Terraform sample and is never deployed) — an OpenAI Agents SDK (TypeScript) HelloWorld. Unlike the Terraform-only provider samples (`terraform/aws/`, `terraform/gc/`), it carries real exact-pinned deps (`@openai/agents`, `zod`) + a committed `bun.lock` + a `tsconfig.json` (+ `@types/bun`) for `bunx tsc --noEmit`; `index.ts` prints setup guidance and exits 0 when `OPENAI_API_KEY` is unset (so a keyless `mise run dev openai` still succeeds), and runs one `Agent` / `run` call printing `finalOutput` when the key is set. It keeps a **flat layout** (`index.ts` at the app root, not `src/index.ts`). See [`apps/openai/README.md`](./apps/openai/README.md).
- **[WARNING] no repo-wide test / lint / typecheck.** `apps/cloud-run-rest/`, `apps/openai/`, and `apps/cost-estimator/` each carry a `tsconfig.json` (+ `@types/bun`) for `bunx tsc --noEmit` (and `cost-estimator` adds `bun test`); `apps/agentcore-strands-basic/`, `apps/agentcore-rag-chat/`, and `apps/adk-helloworld/` each carry `pyproject.toml` + `uv.lock` and verify with `uv run ... python -m unittest`. Everything else runs untyped on Bun. Terraform exists as learning samples with local state only; no remote backend is configured. See "Gotchas".
- Drive everything through mise tasks (`mise run ...`). A bare `bun` is not on PATH, but the tasks wrap it (`mise exec -- bun`), so `mise run` works as-is.

## 1. Orientation (layout)

- `mise.toml` — tool versions (`[tools]`) + task definitions (`[tasks.*]`). **The single source of version truth.**
- `tools/bootstrap.sh` — idempotent full setup (`set -euo pipefail`); skips gracefully when mise is absent.
- `tools/git-hooks/commit-msg` — dependency-free bash validator for Conventional Commits (`<type>(<scope>): ...`, fixed type enum, 72-char subject; merge/autosquash skipped). Enabled via `core.hooksPath` by `mise run install-hooks` / `bs`. **scope is free-form, not enum-checked** (keeps the auto-discover model — no per-package config edits).
- `terraform/<provider>/` — provider Terraform-sample roots (no runnable Bun entry point; not reached by `dev`). Currently `aws` and `gc` (their former runnable samples `openai` and `cost-estimator` now live under `apps/`). Each contains `<operation>/` dirs — one independent Terraform root module per cloud operation. AWS includes `caller-identity` (read-only), `s3-private-bucket` (mutating), `s3-object-upload` (mutating), `agentcore-runtime-basic` (mutating, deploys an app under `apps/`), and `agentcore-rag-chat` (mutating, deploys a supervisor + 3 specialist RAG-agent app; 3 Bedrock Knowledge Bases on S3 Vectors + AgentCore Memory); Google Cloud includes `project-info`, storage learning samples, `cloud-run-service-basic` (mutating, deploys an app under `apps/`), and `adk-agent-engine-basic` (mutating, deploys `adk-helloworld` to Vertex AI Agent Engine; prerequisite API via `vertex-ai-api-enable`).
- `apps/<app>/` — deployable / runnable app code, **decoupled from any single provider** and living flat at the repo root (not under a provider package). Six apps today; four back a Terraform deploy sample, while `openai` (an SDK sample) and `cost-estimator` (the AWS cost-estimation tool) are runnable apps that are never deployed: `agentcore-strands-basic` (Python 3.13 + uv + Strands Agents, packaged as an AWS AgentCore Runtime direct code deployment ZIP; verified with `mise exec -- uv run --directory apps/agentcore-strands-basic --locked python -m unittest discover -s tests` and packaged with `apps/agentcore-strands-basic/scripts/package.sh`); `agentcore-rag-chat` (Python 3.13 + uv + Strands Agents + bedrock-agentcore + boto3; a supervisor + 3 specialist RAG agents over 3 Bedrock Knowledge Bases on S3 Vectors with short-term AgentCore Memory, backing `terraform/aws/agentcore-rag-chat/`; flat `main.py` entry + `rag_chat/` package + a local `chat.py` REPL, verified with `mise exec -- uv run --directory apps/agentcore-rag-chat --locked python -m unittest discover -s tests` and packaged with `apps/agentcore-rag-chat/scripts/package.sh`); `adk-helloworld` (Python 3.13 + uv Google ADK HelloWorld whose package `hello_world/` exposes `root_agent`, run locally via `adk run` / `adk web`; it also backs `adk-agent-engine-basic` by generating an inline-source archive via `scripts/package-agent-engine.sh`, whose `.build/` output is gitignored, with the Agent-Engine-only files under `agent-engine/`); `cloud-run-rest` (a Bun REST service — zero **runtime** deps, `@types/bun` dev-only — plus a Dockerfile for the `cloud-run-service-basic` Terraform sample); `openai` (a runnable OpenAI Agents SDK TypeScript HelloWorld — backs no Terraform sample and is never deployed; flat layout with `index.ts` / `chat.ts` / `web.ts` / `chat.html` at the app root, run via `mise run dev` / `chat` / `web openai`); and `cost-estimator` (a non-Terraform AWS cost-estimation CLI with a `bun test` suite — also never deployed; flat layout, detailed below). Bun apps use `src/index.ts` as the entry point — except the flat `openai` and `cost-estimator`, whose entry is `index.ts` at the app root; Python apps use their package module (e.g. `hello_world/agent.py`). There is no `dev:all` (provider samples are Terraform-only); the `dev` / `chat` / `web` tasks resolve a runnable `<name>` (a dir with `package.json`) from `apps/`, so `dev` / `chat` / `web openai` and `dev cost-estimator` work. Bootstrap scans `apps/` too — a real `bun install` for `cloud-run-rest`, `openai`, and `cost-estimator` (fetching deps / `@types/bun`), a no-op for the Python apps (no `package.json`).
- `apps/cost-estimator/` — a runnable, non-Terraform app (the AWS cost-estimation tool, moved out of the `aws` provider package): estimation-only YAML catalog under `catalog/<category>.yaml` (loader globs `catalog/*.yaml`), `src/` adapter that converts the catalog into `bcm-pricing-calculator` `BatchCreateWorkloadEstimateUsage` usage entries (each labeled `mapping_status` = `mapped`/`schema_only`/`needs_research`), and a `--submit` wrapper that shells out to the AWS CLI. Entry point `index.ts` (flat at the app root, not `src/`); reachable via `mise run dev cost-estimator`; `bun install` runs in it during bootstrap. `usageAccountId` and AWS creds are never stored — resolved from `--account-id`/`AWS_ESTIMATE_ACCOUNT_ID`/a `000000000000` placeholder and standard AWS auth. See [`apps/cost-estimator/README.md`](./apps/cost-estimator/README.md).
- `apps/openai/` — the **runnable** OpenAI Agents SDK (TypeScript) HelloWorld app (unlike the other apps it backs no Terraform sample and is never deployed). `index.ts` exits 0 with setup guidance when `OPENAI_API_KEY` is unset (so a keyless `mise run dev openai` still succeeds) and otherwise runs one `Agent` / `run` call printing `finalOutput`. Carries exact-pinned `@openai/agents` + `zod`, a committed `bun.lock`, and a `tsconfig.json` (+ `@types/bun`) for `bunx tsc --noEmit` (its `moduleDetection: "force"` makes the dynamic-import `index.ts` a module so top-level `await` type-checks). It keeps a **flat layout** (`index.ts` / `chat.ts` / `web.ts` / `chat.html` at the app root, not `src/`). `OPENAI_DEFAULT_MODEL` overrides the SDK default model. Also ships a terminal chat (`mise run chat openai` → `chat.ts`) and a minimal Bun.serve web chat UI (`mise run web openai` → `web.ts` + `chat.html`, streams responses), both multi-turn via the SDK's `run()` history. See [`apps/openai/README.md`](./apps/openai/README.md).
- `.claude/` and `.codex/` — agent tooling for this repo; see §8.

## 2. Run

mise tasks execute inside mise's resolved environment, so they are copy-paste safe.

| Purpose | Command | Notes |
| --- | --- | --- |
| Full setup | `mise run bs` | alias of `bootstrap`; breakdown below |
| Enable commit hook | `mise run install-hooks` | sets `core.hooksPath=tools/git-hooks` (also run by `bs`) |
| Run one app | `mise run dev <name>` | resolves a runnable `<name>` (a dir with `package.json`) from `apps/`; today `openai` / `cost-estimator` |
| Interactive chat | `mise run chat <name>` | resolves `<name>` from `apps/`; only `openai` (under `apps/`) has a `chat` script today |
| Web chat UI | `mise run web <name>` | minimal Bun.serve + HTML streaming chat; only `openai` (under `apps/`) has a `web` script today |
| List tasks | `mise tasks` | shows registered tasks |

`mise run bs` (`tools/bootstrap.sh`) does:

1. `mise install` at root (after `mise trust`; skipped if mise is missing).
2. Scans `terraform/*`; runs `mise install` **only in dirs that have their own `mise.toml` / `.mise.toml`** (the rest inherit root config).
3. Runs `mise exec -- bun install` in every dir that has a `package.json`.

> [WARNING] A bare `bun` is **not on the shell PATH** (mise-managed, shell not activated). Typing `bun ...` directly returns `command not found` (exit 127).
> - `mise run dev` works regardless — its task definition calls `mise exec -- bun`.
> - For a manual bun, prefix `mise exec -- ` (e.g. `mise exec -- bun run start`, `mise exec -- bun --version`).
> - For interactive use, activate the shell: `eval "$(mise activate zsh)"`. See README's "shell への activate（推奨）".

## 3. Change

Add a runnable app (reference: `apps/openai/`) — or run the `/new-package <name>` skill:

1. Create `apps/<name>/`.
2. Add `package.json`: `"private": true`, `"type": "module"`, `"scripts": { "start": "bun run index.ts" }`.
3. Add `index.ts` (entry point; flat at the app root like `apps/openai/`, or `src/index.ts` like `apps/cloud-run-rest/`).
4. Only if the app needs a different tool/version, add a `mise.toml` (or hidden `.mise.toml`; bootstrap detects both) and run `mise trust` before use (it merges over root).

Bootstrap auto-discovers `terraform/` + `apps/` via `find`, so **no task edits are needed** when adding one; `mise run dev <name>` then resolves it. (A new Terraform sample instead goes under `terraform/<provider>/<operation>/` — see below.)

Terraform learning samples:

- `terraform/aws/<operation>/` — each AWS operation is a self-contained, independent root module (own state) placed directly under `terraform/aws/`. Current samples include `caller-identity` (read-only, uses `data "aws_caller_identity" "current" {}` only), `s3-private-bucket` (mutating, creates a private S3 bucket and public access block), `s3-object-upload` (mutating, uploads a local file to an existing S3 bucket), `agentcore-runtime-basic` (mutating, creates S3 artifact storage, IAM, AgentCore Runtime, and a custom endpoint from a prebuilt ZIP), and `agentcore-rag-chat` (mutating, creates AgentCore Runtime / endpoint / Memory, 3 Bedrock Knowledge Bases on an S3 Vectors bucket + 3 indexes, a data-source S3 bucket, and 2 IAM roles; KB ingestion is run out-of-band via `aws bedrock-agent start-ingestion-job`).
  - Run via the `tf` task: `mise run tf <operation> <command>` (e.g. `mise run tf caller-identity plan`), or directly `mise exec -- terraform -chdir=terraform/aws/<operation> ...`.
  - Add one: create `<operation>/` under `terraform/aws/` (copy `terraform.tf` / `providers.tf` so it stays self-contained), then add a row to `terraform/aws/README.md` (the shared-workflow index).
- `terraform/gc/<operation>/` — each Google Cloud operation is a self-contained, independent root module (own state) placed directly under `terraform/gc/`. First sample: `project-info`, which reads `data "google_project" "current"` with a `postcondition` asserting the project number for `nck-sakurai`. API enablement is factored into dedicated `*-api-enable` samples (`storage-api-enable` for one API; `cloud-run-api-enable` enables the `run` / `artifactregistry` / `cloudbuild` trio via `google_project_service` with `for_each`), each `disable_on_destroy = false` so cleanup never turns an API off. `cloud-run-service-basic` (mutating) creates an Artifact Registry repository + a private Cloud Run v2 service (its prerequisite APIs come from `cloud-run-api-enable`, applied first); the container image is built/pushed via `gcloud builds submit` (not Terraform), so its README documents a two-stage apply (`-target` the repository first). `vertex-ai-api-enable` enables `aiplatform.googleapis.com` (same `disable_on_destroy = false` pattern; sufficient alone for the inline-source path — no storage/cloudbuild). `adk-agent-engine-basic` (mutating) creates a `google_vertex_ai_reasoning_engine` from an inline-source archive read via `filebase64(var.source_archive_path)`; the archive is built outside Terraform by `apps/adk-helloworld/scripts/package-agent-engine.sh` (infra=Terraform / artifact=script), its `python_spec` entrypoint is an `AdkApp` wrapper (`agent_engine_app:agent_engine`, not the raw `root_agent`), and runtime identity stays on the provider default (no dedicated SA). All variables have defaults, so `validate` passes without the archive (`filebase64` is deferred to plan/apply).
  - Not covered by the `tf` task (which targets AWS samples); run directly with `mise exec -- terraform -chdir=terraform/gc/<operation> ...`.
  - Add one: create `<operation>/` under `terraform/gc/` (copy `terraform.tf` / `providers.tf` so it stays self-contained), then add a row to `terraform/gc/README.md` (the shared-workflow index).
- read-only samples do not create, update, or destroy resources. mutating samples are marked in each Terraform README and must document cleanup / `destroy`. Credentials come from each provider's standard mechanism (AWS env / profile; Google ADC) — never hardcoded.

## 4. Verify

> No test runner / typechecker is configured, so verification today means "run it and check the output."

- After a change to a runnable app: `mise run dev <name>` exits cleanly (e.g. `mise run dev openai` prints its guidance, `mise run dev cost-estimator` prints the estimate JSON).
- Runnable apps: `mise run dev openai` and `mise run dev cost-estimator` run without crashing (there is no `dev:all`; provider samples `aws`/`gc` are Terraform-only).
- Version pinning: `mise current` matches `mise.toml` `[tools]`.
- Environment problems: delegate to the `env-doctor` agent (mise / bun / trust / run / git checks).
- `apps/cloud-run-rest/` and `apps/openai/` each have a `tsconfig.json` + `@types/bun`, so `mise exec -- bunx tsc --noEmit` (run from that dir) typechecks them today. No repo-wide typecheck task is wired into `mise.toml` yet.
- `apps/agentcore-strands-basic/` has a `pyproject.toml` + `uv.lock`; run `mise exec -- uv lock --directory apps/agentcore-strands-basic --check`, `mise exec -- uv run --directory apps/agentcore-strands-basic --locked python -m unittest discover -s tests`, and `apps/agentcore-strands-basic/scripts/package.sh` for its local verification.
- `apps/agentcore-rag-chat/` has a `pyproject.toml` + `uv.lock`; run `mise exec -- uv lock --directory apps/agentcore-rag-chat --check`, `mise exec -- uv run --directory apps/agentcore-rag-chat --locked python -m unittest discover -s tests`, and `apps/agentcore-rag-chat/scripts/package.sh` for its local verification. The unittest suite injects fakes for the boto3 `bedrock-agent-runtime` client, the supervisor agent, and the `MemoryClient`, so it never calls live Bedrock / Knowledge Base / Memory.
- `apps/adk-helloworld/` has a `pyproject.toml` + `uv.lock`; run `mise exec -- uv lock --directory apps/adk-helloworld --check` and `mise exec -- uv run --directory apps/adk-helloworld --locked python -m unittest discover -s tests` for its local verification (the agent itself runs via `adk run` / `adk web` — see its README). The unittest suite also includes `test_agent_engine_packaging.py`, a stdlib-only guard that the Agent Engine `requirements.txt` `google-adk` pin stays in sync with `pyproject.toml` and that `agent-engine/agent_engine_app.py` wraps `root_agent` in `AdkApp`; `scripts/package-agent-engine.sh` builds the Agent Engine deploy archive (output under the gitignored `.build/`).
- Root `pyrightconfig.json` (repo root) gives Pyright / Pylance one `executionEnvironments` entry per Python app, each mapping the app dir (`root`) to its own gitignored `apps/<app>/.venv/lib/python3.13/site-packages` via `extraPaths`. Without it, an editor opened at the monorepo root resolves imports against a single interpreter and flags venv-only packages (e.g. `bedrock_agentcore`) as unresolved. The `python3.13` segment is pinned to match `mise.toml` `[tools]` `python` (same "tool config can't read `mise.toml`" exception as `apps/cloud-run-rest/Dockerfile`) — bump both on a minor-version change; a `.venv` only needs `uv sync` for the path to populate.
- [Recommended · not set up yet] a repo-wide typecheck / lint / test / formatter is still **undecided**. If you add one (e.g. `bun test` with `*.test.ts`, or a root `tsc --noEmit`), wire it into `apps/*/package.json` scripts, `mise.toml` tasks, and this doc **together**. **This is a recommendation, not a command that works today.**

Note: the provider Terraform-sample roots `terraform/aws/` and `terraform/gc/` hold only `<operation>/` dirs (no `package.json`), so bootstrap runs no `bun install` there — that is expected, not an error.

## 5. Conventions (internalize before acting)

- [OK] Pin exact tool versions in `mise.toml`. [NG] `latest` / `any`, or hardcoding version numbers in docs/scripts. Check with `mise current`.
- [OK] Versions live **only** in `mise.toml` — this doc never spells out a version number. Exception: a `Dockerfile` base image can't read `mise.toml`, so it pins the same version explicitly (e.g. `apps/cloud-run-rest/Dockerfile` ↔ `[tools]` `bun`) — update both together.
- [OK] `mise trust` any new `mise.toml` / `.mise.toml` before use (bootstrap auto-trusts; do it yourself for manually created ones).
- [OK] Shell scripts: `set -euo pipefail`, quote every variable (`"${var}"`), status via `[OK]` / `[NG]` / `[WARNING]` / `[INFO]` markers, no decorative emoji.
- [OK] Secrets: never hardcode. Templates use a `.template` suffix; machine-specific values go in `.local` files or env vars.
- [OK] Consistency: when you change config / CLI flags / docs / CI / code, update all related places together.
- [OK] Text style for any Japanese (e.g. README): half-width space between latin and Japanese (`Flutter アプリ`), no space between a number and Japanese (`3個`, `2025年`).
- Link, don't copy: point to [README.md](./README.md) for human setup detail instead of duplicating it.

### Strands Agents SDK work

When designing, implementing, or reviewing code that uses `strands-agents`,
Amazon Bedrock AgentCore, multi-agent systems, tools, MCP tools, or
agents-as-tools:

- Check the relevant official Strands Agents SDK documentation before making
  Strands-specific design or review claims. In Claude Code, prefer the project
  `strands` MCP server when it is available; otherwise use the active
  environment's official-doc search or the public Strands docs.
- Explicitly identify the applicable Strands pattern: model-driven agent,
  custom tools, MCP tools, multi-agent, agents-as-tools, memory/session,
  streaming, model provider configuration, or AgentCore deployment.
- Prefer the documented Strands pattern over ad hoc orchestration. Keep
  specialist agents focused, tool names/descriptions clear, response handling
  explicit, and AWS credentials/configuration external to code.
- If the Strands documentation tool is unavailable, say so before making
  claims that depend on current Strands behavior.
- For a repeatable design or review workflow, use the
  `strands-design-review` project skill.

## 6. Gotchas

- **git is initialized.** Branches / commits / PRs apply. Follow the global conventions: branch `{prefix}/GH-{issue}` when an issue exists, otherwise `{prefix}/{kebab-case-description}`; commit `{type}({scope}): {Japanese description}`.
- **`bun: command not found` (exit 127).** Shell not activated — use `mise exec -- bun ...` or `eval "$(mise activate zsh)"`. Does not affect `mise run dev`.
- **Terraform samples include read-only and mutating examples.** `terraform/aws/<operation>/` and `terraform/gc/<operation>/` hold one independent root module per cloud operation. Mutating samples follow the same flat `terraform/<provider>/<operation>/` layout — distinguished by the README's 種別 column, not a separate tree — and must include cleanup / `destroy` guidance. No remote backend is configured, and bootstrap does no provisioning.
- **Lockfile / tsconfig / pyproject: not everything has them.** The provider Terraform-sample roots `terraform/aws/` and `terraform/gc/` are Terraform-only (no `package.json` / `bun.lock` / `tsconfig.json`). Bun runs TypeScript / ESM natively without a `tsconfig.json`, so a runnable app's `index.ts` runs directly with no typecheck step. The TypeScript exceptions are `apps/cloud-run-rest/` and `apps/cost-estimator/`: each carries `@types/bun`, a committed `bun.lock` (repeatable installs, like Terraform's committed `.terraform.lock.hcl`), and a `tsconfig.json` enabling `bunx tsc --noEmit` (`cost-estimator` also adds `bun test` and `exactOptionalPropertyTypes`). `apps/openai/` is a third TypeScript case: a runnable app carrying exact-pinned `@openai/agents` + `zod`, a committed `bun.lock`, `@types/bun`, and a `tsconfig.json` whose `moduleDetection: "force"` makes the dynamic-import `index.ts` a module (so top-level `await` type-checks and `bunx tsc --noEmit` passes). The Python exceptions are `apps/agentcore-strands-basic/`, `apps/agentcore-rag-chat/`, and `apps/adk-helloworld/`, which each carry `pyproject.toml` + `uv.lock` and use package-local `uv` / `unittest` checks. These are still package-local — don't assume a repo-wide typecheck exists.

## 7. Troubleshooting (symptom -> fix)

- `bun: command not found` -> shell not activated. Prefix `mise exec -- bun ...`, or run `eval "$(mise activate zsh)"`.
- `mise install` / `mise run` asks to trust -> run `mise trust` (a new or changed `mise.toml` was detected).
- `mise run dev <name>` does nothing -> check `apps/<name>/` has a `package.json` with `scripts.start` — provider samples `aws`/`gc` are Terraform-only and not runnable — and `mise run bs` has run.
- `mise: command not found` -> mise is not installed. See <https://mise.jdx.dev/getting-started.html>.

## 8. Agent tooling (.claude / .codex)

Project-scoped config for the coding agents. Both Claude Code and Codex are wired up; they share the same skill, kept in sync across the two trees.

Shared MCP:

- `.mcp.json` — project-scoped Claude Code MCP server config. It registers the `strands` server (`uvx strands-agents-mcp-server`) so Strands Agents SDK design/review work can query official docs after Claude Code approves the project-scoped server.

Claude Code (`.claude/`, auto-loaded):

- `.claude/agents/env-doctor.md` — subagent that diagnoses the toolchain / bootstrap state.
- `.claude/skills/new-package/` — `/new-package <name>` slash command to scaffold a project.
- `.claude/skills/strands-design-review/` — Strands Agents SDK / AgentCore design and review workflow. Use it before Strands-specific architecture or review claims; it expects the Claude Code `strands` MCP server when available.
- `.claude/rules/*.md` — path-scoped conventions, auto-loaded when editing matching files: `projects.md`, `shell.md`, `mise.md`.

Codex (`.codex/`, loaded for trusted projects):

- `.codex/skills/new-package/SKILL.md` — the Codex twin of the Claude `new-package` skill (verified to surface in Codex's "Available skills"). Keep the two `new-package/SKILL.md` files in sync.
- `.codex/skills/strands-design-review/SKILL.md` — the Codex twin of the Claude `strands-design-review` skill. Keep the two `strands-design-review/SKILL.md` files in sync.
- `.codex/hooks.json` — a live `session_start` hook printing a one-line repo reminder. Codex asks you to approve the hook (trusted hash) on first run. Schema/details in `.codex/hooks/README.md`.
- `.codex/config.toml` — Codex project config (options commented out by default).
- `.codex/rules/` — empty: the Codex permission-rules feature (`request_rule`) is removed in the installed CLI; see its `README.md`.
- **Project instructions for Codex live in this `AGENTS.md`** (merged git-root → cwd), not under `.codex/`. Note: this repo is not yet in Codex's trusted-projects list, so trust it in Codex for `.codex/` to take full effect.
