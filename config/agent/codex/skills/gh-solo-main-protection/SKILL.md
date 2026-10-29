---
name: gh-solo-main-protection
description: "Configure Solo Main Protection when the user requests GitHub default-branch protection."
---

# gh-solo-main-protection

When the preserved workflow conflicts with this entrypoint or current user and environment rules, follow this entrypoint and the active rules.

Read workflow.md for the original ruleset shape: deletion and force-push protection, linear history, PRs with zero approvals, and resolved review threads.
Determine repo and default branch from actual remotes/GitHub. Inspect existing rulesets to avoid duplicates. Verify current API and preserve unrelated rules.
The legacy example includes an admin bypass. Do not grant or expand it without explicit authorization; treat it as a separate decision when absent.
Apply only requested changes, read them back, and report the ruleset URL. Request submission alone is not verification.
