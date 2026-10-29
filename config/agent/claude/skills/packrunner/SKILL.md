---
name: packrunner
description: >-
  Turn selected Jira tickets into scoped implementation work when the user
  requests a batch of issues.
---

# packrunner

Inspect connected Jira tools, selected issues, repo rules, and actual callers. Use the user's project and label; do not default to a Claude label.
For each ticket define problem, intended behavior, scope, acceptance checks, dependencies, and missing decisions. Ask a few concrete questions only for real ambiguity. Jira writes require authorization.
Order work by dependencies and overlapping files. Default to sequential execution; use subagents/worktrees only when authorized. Preserve unrelated dirty changes and isolate concurrent checkouts.
Fix root causes, reuse helpers, run relevant checks, and give per-ticket status and integration order.
Do not infer completion from code alone or merge, publish, or change issue status without authorization.
