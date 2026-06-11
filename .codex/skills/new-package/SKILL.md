---
name: new-package
description: >-
  Scaffold a new runnable app under apps/ in the workshop monorepo, following the
  established convention (a private ESM package: package.json with
  scripts.start = "bun run index.ts", plus an index.ts entry point). Use when the
  user wants to add a new runnable app or project to this monorepo.
metadata:
  short-description: Scaffold an apps/ runnable app
---

# new-package

Scaffold a new runnable app at `apps/<name>/` matching the repo convention (reference: `apps/openai/`).

> Runnable / deployable code lives under `apps/`. The provider packages `packages/aws/` and `packages/gc/` are Terraform-sample containers (no runnable Bun entry point) — a new Terraform sample instead goes under `packages/<provider>/terraform/<operation>/`.

## Steps

1. Choose `<name>` (lowercase, no spaces, matching the `openai` / `cost-estimator` style). Confirm `apps/<name>/` does not already exist.
2. Create `apps/<name>/package.json`:
   ```json
   {
     "name": "<name>",
     "version": "0.1.0",
     "private": true,
     "type": "module",
     "scripts": { "start": "bun run index.ts" }
   }
   ```
3. Create `apps/<name>/index.ts` with a minimal entry point, e.g. `console.log("Hello from <name>");`.
4. Install deps and register: `mise run bs` (it auto-discovers the new app).
5. Verify: `mise run dev <name>` runs without error and prints the expected output.

## Notes

- Do **not** edit `mise.toml` tasks — `dev` / `chat` / `web` resolve `<name>` (a dir with `package.json`) from `packages/` then `apps/`, and bootstrap auto-detects new dirs. There is no `dev:all`.
- `bun` is mise-managed and not on PATH; run it via `mise run` or `mise exec -- bun ...`.
- Add a project-local `mise.toml` (+ `mise trust`) only if this app needs a tool/version different from root.
- Tool versions live in `mise.toml`, never in `package.json` (beyond the package's own `version`).

This is the Codex twin of the Claude Code skill at `.claude/skills/new-package/SKILL.md` — keep the two in sync.
