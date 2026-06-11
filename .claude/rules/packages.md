---
paths:
  - "packages/**"
  - "apps/**"
---

# packages/ & apps/ conventions

`packages/<provider>/` holds provider Terraform-sample containers (just `terraform/<operation>/`; no runnable Bun entry point — `aws`, `gc`). Runnable / deployable code lives in `apps/<app>/`. There are no root npm workspaces.

- A **runnable app**'s `package.json` must set `"private": true`, `"type": "module"`, and `"scripts": { "start": "bun run index.ts" }` (or `src/index.ts`).
- Entry point: flat `index.ts` at the app root (e.g. `apps/openai/`) or `src/index.ts` (e.g. `apps/cloud-run-rest/`). Bun runs TypeScript / ESM natively — no build step and no `tsconfig.json` are required (`cloud-run-rest` / `openai` / `cost-estimator` add one anyway, for editor / `tsc` type-checking only; see below).
- Root-level apps (`apps/<app>/`, e.g. `apps/cloud-run-rest/`) are app code **decoupled from any single provider** (they live flat at the repo root, not under a provider package). Most back a Terraform sample and are deployable; the exceptions are `apps/openai/` and `apps/cost-estimator/`, runnable samples that back no Terraform sample and are never deployed. Bun apps use `src/index.ts` as the entry point — **except** the flat `openai` and `cost-estimator`, whose entry is `index.ts` at the app root. There is no `dev:all`, but the `dev` / `chat` / `web` tasks resolve a runnable `<name>` (a dir with `package.json`) from `packages/` then `apps/` (so `mise run dev openai` reaches it), and bootstrap scans `apps/` and runs `bun install` in them. `cloud-run-rest`, `openai`, and `cost-estimator` each carry `@types/bun` (dev-only) + a `tsconfig.json` so `bunx tsc --noEmit` type-checks them; their `bun.lock` is committed for repeatable installs.
- Reference implementation — runnable app: `apps/openai/` (flat) or `apps/cloud-run-rest/` (`src/`); Terraform-sample container: `packages/aws/`.
- Run one: `mise run dev <name>` — resolves a runnable `<name>` (a dir with `package.json`) from `packages/` then `apps/`. There is no `dev:all`.
- `tools/bootstrap.sh` auto-discovers `packages/` + `apps/` via `find`; `dev` / `chat` / `web` resolve a `<name>` from `packages/` then `apps/` — never hand-edit task lists when adding an app.
- `bun` is mise-managed and not on PATH; call it as `mise exec -- bun ...` (mise tasks already wrap it).
- No repo-wide test / lint / typecheck task is configured yet (though `cloud-run-rest` / `openai` / `cost-estimator` can be type-checked with `bunx tsc --noEmit`, and `cost-estimator` runs `bun test`). If you add a repo-wide one, wire it into `package.json` scripts, `mise.toml` tasks, and `AGENTS.md` together.
- Add a project-local `mise.toml` only when the app needs a tool/version different from root; then run `mise trust`.
- A new Terraform sample goes under `packages/<provider>/terraform/<operation>/` (own state); register it in that provider's `terraform/README.md`.

## Python apps

Some apps are Python instead of Bun (first: `apps/agentcore-strands-basic/`). Keep them self-contained — any app lives flat at `apps/<app>/`, regardless of which cloud provider's Terraform sample it backs.

- Each Python app owns its own `pyproject.toml` + `uv.lock` + `.venv/` (managed by [uv](https://docs.astral.sh/uv/)); `.venv/` is gitignored. Pin exact dependency versions (`==`), per the repo-wide version-pinning rule.
- **Name the virtualenv `.venv`** (not `venv` or a custom name). The VS Code Python Environments extension auto-discovers `./**/.venv`, so a correctly-named venv is found without any per-project interpreter path.
- Register each Python app in the committed `.vscode/settings.json` under `python-envs.pythonProjects` (`{ "path": "...", "envManager": "ms-python.python:venv" }`). This is portable — it stores a relative path + env-manager type, never a machine-specific interpreter path. Do **not** add per-project `python.defaultInterpreterPath` lines: that setting takes a single path and does not scale to multiple Python apps.
- Pylance resolves one interpreter per workspace folder, so in this single-root workspace only one Python app's imports resolve at a time — fine when working on one app. If you ever need several Python apps resolved simultaneously, switch to a multi-root `.code-workspace` (one folder per app); defer that until actually needed.
- Not runnable via `dev` (no `package.json`); bootstrap's recursive `find` runs in them but `bun install` is a no-op. Build / test via uv — see the app's README.
