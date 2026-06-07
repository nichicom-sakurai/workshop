# AGENTS.md

AI-agent guide for the `workshop` monorepo. For human-facing detail, see [README.md](./README.md) (Japanese).

> This file is the real target of the `CLAUDE.md` symlink (`CLAUDE.md` -> `AGENTS.md`).
> Claude Code reads it as `CLAUDE.md`, Codex reads it as `AGENTS.md`, and the content is identical — **editing this file updates both**. Edit `AGENTS.md`, never `CLAUDE.md` directly (writing the symlink path would break the link).
> This doc is in English per the global "AI docs in English" convention; `README.md` stays Japanese for human contributors.

## TL;DR (read first)

- **Cloud / IaC learning monorepo.** Independent projects live in `packages/<name>/`. Tool versions are centrally pinned by [mise](https://mise.jdx.dev/) in `mise.toml`.
- **Skeleton stage.** `packages/{aws,gc,sample}/` are just `package.json` + `index.ts` (`console.log("Hello from <name>")`). No real cloud / IaC code exists yet.
- **[WARNING] git is not initialized · no test / lint / typecheck / tsconfig · terraform is installed but unused (no `.tf` files).** See "Gotchas".
- Drive everything through mise tasks (`mise run ...`). A bare `bun` is not on PATH, but the tasks wrap it (`mise exec -- bun`), so `mise run` works as-is.

## 1. Orientation (layout)

- `mise.toml` — tool versions (`[tools]`) + task definitions (`[tasks.*]`). **The single source of version truth.**
- `tools/bootstrap.sh` — idempotent full setup (`set -euo pipefail`); skips gracefully when mise is absent.
- `packages/*` — the projects. Targets of `bun install` / `dev` / `dev:all`. Each is independent (no root npm workspaces). Currently `aws`, `gc`, `sample`.
- `.claude/` and `.codex/` — agent tooling for this repo; see §8.

## 2. Run

mise tasks execute inside mise's resolved environment, so they are copy-paste safe.

| Purpose | Command | Notes |
| --- | --- | --- |
| Full setup | `mise run bs` | alias of `bootstrap`; breakdown below |
| Run one project | `mise run dev <name>` | `<name>` is `aws` / `gc` / `sample` |
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

Add a project (reference: `packages/aws/`) — or run the `/new-package <name>` skill:

1. Create `packages/<name>/`.
2. Add `package.json`: `"private": true`, `"type": "module"`, `"scripts": { "start": "bun run index.ts" }`.
3. Add `index.ts` (entry point).
4. Only if the project needs a different tool/version, add a `mise.toml` (or hidden `.mise.toml`; bootstrap detects both) and run `mise trust` before use (it merges over root).

`dev:all` and bootstrap auto-discover packages via `find`, so **no task edits are needed** when adding one.

## 4. Verify

> No test runner / typechecker is configured, so verification today means "run it and check the output."

- After a change: `mise run dev <name>` exits cleanly and prints `Hello from <name>`.
- Integration: `mise run dev:all` runs all projects (aws / gc / sample) without crashing.
- Version pinning: `mise current` matches `mise.toml` `[tools]`.
- Environment problems: delegate to the `env-doctor` agent (mise / bun / trust / run / git checks).
- [Recommended · not set up yet] typecheck / lint / test / formatter are all **undecided**. If you add one (e.g. `bun test` with `*.test.ts`, or `tsc --noEmit` after adding a `tsconfig.json`), wire it into `packages/*/package.json` scripts, `mise.toml` tasks, and this doc **together**. **This is a recommendation, not a command that works today.**

Note: skeleton packages have no dependencies, so `bun install` creates no `node_modules/` — its absence is not an error.

## 5. Conventions (internalize before acting)

- [OK] Pin exact tool versions in `mise.toml`. [NG] `latest` / `any`, or hardcoding version numbers in docs/scripts. Check with `mise current`.
- [OK] Versions live **only** in `mise.toml` — this doc never spells out a version number.
- [OK] `mise trust` any new `mise.toml` / `.mise.toml` before use (bootstrap auto-trusts; do it yourself for manually created ones).
- [OK] Shell scripts: `set -euo pipefail`, quote every variable (`"${var}"`), status via `[OK]` / `[NG]` / `[WARNING]` / `[INFO]` markers, no decorative emoji.
- [OK] Secrets: never hardcode. Templates use a `.template` suffix; machine-specific values go in `.local` files or env vars.
- [OK] Consistency: when you change config / CLI flags / docs / CI / code, update all related places together.
- [OK] Text style for any Japanese (e.g. README): half-width space between latin and Japanese (`Flutter アプリ`), no space between a number and Japanese (`3個`, `2025年`).
- Link, don't copy: point to [README.md](./README.md) for human setup detail instead of duplicating it.

## 6. Gotchas

- **git is not initialized.** Not a git repo (`git rev-parse` fails, no `.git`). Branches / commits / PRs don't apply until `git init`; confirm with the user before assuming git workflows. After init, follow the global `CLAUDE.md` conventions (branch `{prefix}/GH-{issue}`, commit `{type}({scope}): {description}`).
- **`bun: command not found` (exit 127).** Shell not activated — use `mise exec -- bun ...` or `eval "$(mise activate zsh)"`. Does not affect `mise run dev` / `dev:all`.
- **terraform is unused.** Pinned in `mise.toml` and installed (`mise exec -- terraform version`), but there are no `.tf` files and bootstrap does no provisioning. It's a forward declaration for future IaC projects — don't try to use it yet.
- **No lockfiles / tsconfig.** Neither `bun.lock` nor `tsconfig.json` is committed; bun runs TypeScript / ESM natively, so `index.ts` runs directly. There is no typecheck step — don't assume one exists.

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
