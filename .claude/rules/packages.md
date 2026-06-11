---
paths:
  - "packages/**"
  - "apps/**"
---

# packages/* conventions

Each project under `packages/<name>/` is an independent, private package — there are no root npm workspaces.

- `package.json` must set `"private": true`, `"type": "module"`, and `"scripts": { "start": "bun run index.ts" }`.
- `index.ts` is the entry point. Bun runs TypeScript / ESM natively — no build step and no `tsconfig.json` are required (the app `cloud-run-rest` adds one anyway, for editor / `tsc` type-checking only; see below).
- Root-level apps (`apps/<app>/`, e.g. `apps/cloud-run-rest/`) are deployable app code used by Terraform samples, **decoupled from any single provider** (they live flat at the repo root, not under a provider package) — they use `src/index.ts` as the entry point instead. They are not picked up by `dev:all` (its loop covers top-level `packages/` only), but bootstrap scans `apps/` and runs `bun install` in them. `cloud-run-rest` carries `@types/bun` (dev-only) + a `tsconfig.json` so `bunx tsc --noEmit` type-checks it; its `bun.lock` is committed for repeatable installs.
- Reference implementation: `packages/aws/`.
- Run one: `mise run dev <name>`. Run all: `mise run dev:all`.
- `dev`, `dev:all`, and `tools/bootstrap.sh` auto-discover packages via `find` — never hand-edit task lists when adding a project.
- `bun` is mise-managed and not on PATH; call it as `mise exec -- bun ...` (mise tasks already wrap it).
- No repo-wide test / lint / typecheck task is configured yet (though `cloud-run-rest` can be type-checked with `bunx tsc --noEmit`). If you add a repo-wide one, wire it into `package.json` scripts, `mise.toml` tasks, and `AGENTS.md` together.
- Add a project-local `mise.toml` only when the package needs a tool/version different from root; then run `mise trust`.

## Python apps

Some apps are Python instead of Bun (first: `apps/agentcore-strands-basic/`). Keep them self-contained — any app lives flat at `apps/<app>/`, regardless of which cloud provider's Terraform sample it backs.

- Each Python app owns its own `pyproject.toml` + `uv.lock` + `.venv/` (managed by [uv](https://docs.astral.sh/uv/)); `.venv/` is gitignored. Pin exact dependency versions (`==`), per the repo-wide version-pinning rule.
- **Name the virtualenv `.venv`** (not `venv` or a custom name). The VS Code Python Environments extension auto-discovers `./**/.venv`, so a correctly-named venv is found without any per-project interpreter path.
- Register each Python app in the committed `.vscode/settings.json` under `python-envs.pythonProjects` (`{ "path": "...", "envManager": "ms-python.python:venv" }`). This is portable — it stores a relative path + env-manager type, never a machine-specific interpreter path. Do **not** add per-project `python.defaultInterpreterPath` lines: that setting takes a single path and does not scale to multiple Python apps.
- Pylance resolves one interpreter per workspace folder, so in this single-root workspace only one Python app's imports resolve at a time — fine when working on one app. If you ever need several Python apps resolved simultaneously, switch to a multi-root `.code-workspace` (one folder per app); defer that until actually needed.
- Not picked up by `dev:all`; bootstrap's recursive `find` runs in them but `bun install` is a no-op (no `package.json`). Build / test via uv — see the app's README.
