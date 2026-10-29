---
name: audit-duplicates
description: "Review duplicated code and recommend justified consolidations when requested."
---

# audit-duplicates

When the preserved workflow conflicts with this entrypoint or current user and environment rules, follow this entrypoint and the active rules.

Read workflow.md for finding format. Inspect definitions, relevant callers, tests, and conventions.
Flag duplication only when shared change boundaries reduce real maintenance or divergence risk; similar syntax alone is insufficient.
Report priority, exact occurrences, shared behavior, impact, and smallest consolidation location/API. Reuse existing helpers; avoid speculative abstractions.
Read-only audits do not authorize edits. Requested fixes must preserve behavior and run a relevant check.
