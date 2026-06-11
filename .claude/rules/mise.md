---
paths:
  - "mise.toml"
  - "**/mise.toml"
  - "**/.mise.toml"
---

# mise.toml conventions

- `mise.toml` is the single source of truth for tool versions. Never hardcode versions in docs or scripts.
  - Exception: Dockerfiles can't read `mise.toml`, so they pin the same version explicitly (e.g. `apps/cloud-run-rest/Dockerfile` ↔ `[tools]` `bun`). When bumping a tool version here, update the matching Dockerfile `FROM` tag together.
- Pin exact versions only (e.g. a full `x.y.z`). `latest` / `any` are forbidden.
- After creating or editing a `mise.toml` / `.mise.toml`, run `mise trust` in that directory before use.
- A project-local `mise.toml` (under `packages/*` or any subdir) merges over the root config; add one only when a project needs a different tool/version.
- Verify the active toolchain matches the file: `mise current`.
- mise task definitions that invoke `bun` wrap it as `mise exec -- bun ...`.
