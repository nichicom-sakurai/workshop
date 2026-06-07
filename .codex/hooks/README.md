# .codex/hooks/

Codex lifecycle hooks run a command at points in the agent loop. This repo ships
a live hook in **`../hooks.json`** (auto-discovered by Codex for trusted projects):
a `session_start` hook that prints a one-line reminder about the mise / bun / git
state of this repo.

## Schema (verified against the installed Codex CLI)

`.codex/hooks.json` keys events in **snake_case**; each event maps to an array of
matcher groups, and each group has a `hooks` array of command handlers:

```json
{
  "session_start": [
    { "hooks": [ { "type": "command", "command": "…", "timeout": 10 } ] }
  ],
  "pre_tool_use": [
    { "matcher": "shell", "hooks": [ { "type": "command", "command": "…" } ] }
  ]
}
```

- Events: `session_start`, `user_prompt_submit`, `pre_tool_use`, `post_tool_use`,
  `permission_request`, `pre_compact`, `post_compact`, `subagent_start`,
  `subagent_stop`, `stop`, `notification`.
- `matcher` (optional) filters tool events by tool name; omit it for non-tool
  events like `session_start`.
- A `command` handler receives a JSON event object on stdin and may return a JSON
  decision, or exit non-zero (exit `2`) with a stderr message to block the action.
- Equivalent registration in `.codex/config.toml` uses TOML tables with
  **PascalCase** event names, e.g. `[[hooks.PreToolUse]]` → `[[hooks.PreToolUse.hooks]]`.

## Trust / approval

Hooks are gated by a per-hook trusted hash and by project trust. A newly added or
edited hook does **not** run until you approve it in Codex (and the project is
trusted). Keep loose hook scripts here and reference them by absolute path.

Reference: <https://developers.openai.com/codex/hooks>
