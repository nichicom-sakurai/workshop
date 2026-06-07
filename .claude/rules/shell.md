---
paths:
  - "**/*.sh"
---

# Shell script conventions

- Start every script with `set -euo pipefail`.
- Quote all variable expansions: `"${var}"`.
- Status output uses `[OK]` / `[NG]` / `[WARNING]` / `[INFO]` markers — no decorative emoji. See `tools/bootstrap.sh` for the house style.
- Keep setup scripts idempotent (safe to re-run).
- Prefer `mise exec -- <tool>` so the mise-pinned toolchain is used regardless of shell activation.
