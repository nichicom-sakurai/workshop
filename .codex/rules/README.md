# .codex/rules/

[WARNING] The Codex command-permission "rules" feature (`request_rule`) is reported
as **removed** by the installed Codex CLI (`codex features list`). A `.rules`
(Starlark) file in this directory does **nothing** on this version.

- Project rules and instructions for the agent (conventions, how to build / run /
  verify) belong in `./AGENTS.md`, which Codex merges from the git root down to the
  current directory.
- Command-permission behavior is controlled by `approval_policy` / `sandbox_mode`
  in `.codex/config.toml` (and `~/.codex/config.toml`), not by files here.

This directory is intentionally empty; it can be removed. Reference:
<https://developers.openai.com/codex/config-reference>
