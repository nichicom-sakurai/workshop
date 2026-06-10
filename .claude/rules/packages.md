---
paths:
  - "packages/**"
---

# packages/* conventions

Each project under `packages/<name>/` is an independent, private package — there are no root npm workspaces.

- `package.json` must set `"private": true`, `"type": "module"`, and `"scripts": { "start": "bun run index.ts" }`.
- `index.ts` is the entry point. Bun runs TypeScript / ESM natively — no build step and no `tsconfig.json` are required (the nested app `cloud-run-rest` adds one anyway, for editor / `tsc` type-checking only; see below).
- Nested apps (`packages/<name>/apps/<app>/`, e.g. `packages/gc/apps/cloud-run-rest/`) are deployable app code used by Terraform samples — they use `src/index.ts` as the entry point instead. They are not picked up by `dev:all` (its loop covers top-level packages only), but bootstrap still runs `bun install` in them. `cloud-run-rest` carries `@types/bun` (dev-only) + a `tsconfig.json` so `bunx tsc --noEmit` type-checks it; its `bun.lock` is committed for repeatable installs.
- Reference implementation: `packages/aws/`.
- Run one: `mise run dev <name>`. Run all: `mise run dev:all`.
- `dev`, `dev:all`, and `tools/bootstrap.sh` auto-discover packages via `find` — never hand-edit task lists when adding a project.
- `bun` is mise-managed and not on PATH; call it as `mise exec -- bun ...` (mise tasks already wrap it).
- No repo-wide test / lint / typecheck task is configured yet (though `cloud-run-rest` can be type-checked with `bunx tsc --noEmit`). If you add a repo-wide one, wire it into `package.json` scripts, `mise.toml` tasks, and `AGENTS.md` together.
- Add a project-local `mise.toml` only when the package needs a tool/version different from root; then run `mise trust`.
