---
name: strands-design-review
description: Review or design Strands Agents SDK, Amazon Bedrock AgentCore, multi-agent, tools, MCP tools, or agents-as-tools code against official Strands documentation. Use when planning, implementing, or reviewing apps under apps/agentcore-* or Terraform-backed AgentCore samples.
---

# Strands Design Review

Use this skill to ground Strands Agents SDK design and review work in current
official documentation before making architecture, implementation, or review
claims.

## Workflow

1. Read the local target first: relevant app code, Terraform sample, README, and
   existing tests.
2. Identify the Strands surface involved: model provider configuration, custom
   tools, MCP tools, multi-agent, agents-as-tools, memory/session, streaming,
   structured output, or AgentCore deployment.
3. Query current official Strands documentation before deciding:
   - In Claude Code, prefer the `strands` MCP server (`search_docs` /
     `fetch_doc`) when it is available.
   - In Codex or when the MCP server is unavailable, use official Strands docs
     from `https://strandsagents.com/docs/` through the active documentation or
     web-search tool.
   - If no official documentation source is available, state that blocker and do
     not present Strands-specific behavior as verified.
4. Compare the local code or proposal against the documented pattern and this
   repo's existing conventions.
5. Finish with the docs consulted, the conclusion, gaps or risks, and the
   verification still needed.

## Design Checks

- Keep the Strands approach model-driven: avoid hardcoded orchestration unless
  the docs or local requirements justify it.
- Use tools for external actions and data access; keep tool names and
  descriptions explicit enough for model tool selection.
- For agents-as-tools, keep each specialist focused on one domain, give the
  supervisor clear routing criteria, and make response aggregation explicit.
- Keep AWS account values, credentials, model IDs, Knowledge Base IDs, and local
  runtime values outside committed code.
- Preserve this repo's split between app packaging and Terraform-managed
  infrastructure.

## Review Checks

- Confirm the implementation follows the relevant Strands docs rather than only
  a local example.
- Check tool definitions, specialist prompts, model provider setup, response
  extraction, dependency injection for tests, and error handling.
- Check that tests avoid live Bedrock, Knowledge Base, Memory, and AWS account
  calls unless the task explicitly asks for integration verification.
- Flag missing docs or verification commands when the change affects runtime
  behavior, packaging, Terraform wiring, or user-facing setup.

This is the Codex twin of the Claude Code skill at
`.claude/skills/strands-design-review/SKILL.md` — keep the two in sync.
