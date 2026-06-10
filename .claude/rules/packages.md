---
paths:
  - "packages/**"
---

# packages/* conventions

Each project under `packages/<name>/` is an independent, private package — there are no root npm workspaces.

- `package.json` must set `"private": true`, `"type": "module"`, and `"scripts": { "start": "bun run index.ts" }`.
- `index.ts` is the entry point. Bun runs TypeScript / ESM natively — no build step and no `tsconfig.json` are required.
- Nested apps (`packages/<name>/apps/<app>/`, e.g. `packages/gc/apps/cloud-run-rest/`) are deployable app code used by Terraform samples — they use `src/index.ts` as the entry point instead. They are not picked up by `dev:all` (its loop covers top-level packages only), but bootstrap still runs `bun install` in them.
- Reference implementation: `packages/aws/`.
- Run one: `mise run dev <name>`. Run all: `mise run dev:all`.
- `dev`, `dev:all`, and `tools/bootstrap.sh` auto-discover packages via `find` — never hand-edit task lists when adding a project.
- `bun` is mise-managed and not on PATH; call it as `mise exec -- bun ...` (mise tasks already wrap it).
- No test / lint / typecheck is configured yet. If you add one, wire it into `package.json` scripts, `mise.toml` tasks, and `AGENTS.md` together.
- Add a project-local `mise.toml` only when the package needs a tool/version different from root; then run `mise trust`.
