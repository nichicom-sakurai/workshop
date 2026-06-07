---
name: new-package
description: Scaffold a new project under packages/ in the workshop monorepo, following the established skeleton (private ESM package + bun entry point). Use when the user wants to add a new package or project to the monorepo.
argument-hint: "<name>"
---

# /new-package

Scaffold a new project at `packages/<name>/` matching the repo convention (reference: `packages/aws/`).

## Steps

1. Choose `<name>` (lowercase, no spaces, matching the `aws` / `gc` / `sample` style). Confirm `packages/<name>/` does not already exist.
2. Create `packages/<name>/package.json`:
   ```json
   {
     "name": "<name>",
     "version": "0.1.0",
     "private": true,
     "type": "module",
     "scripts": { "start": "bun run index.ts" }
   }
   ```
3. Create `packages/<name>/index.ts` with a minimal entry point, e.g. `console.log("Hello from <name>");`.
4. Install deps and register: `mise run bs` (it auto-discovers the new package).
5. Verify: `mise run dev <name>` runs without error and prints the expected output.

## Notes

- Do **not** edit `mise.toml` tasks — `dev`, `dev:all`, and bootstrap auto-detect packages.
- Add a project-local `mise.toml` (+ `mise trust`) only if this package needs a tool/version different from root.
- Tool versions live in `mise.toml`, never in `package.json` (beyond the package's own `version`).

This has a Codex twin at `.codex/skills/new-package/SKILL.md` — keep the two in sync.
