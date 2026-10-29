---
name: audit-duplicates
description: Deeply analyze a codebase for duplicated functions, utilities, validation schemas, database/API query patterns, React components, hooks, constants, error handling, and business logic that should be extracted into shared helpers. Use this skill whenever the user asks for a duplication audit, a DRY review, a refactor opportunity scan, or wants to find copy-pasted code, repeated utilities, or shared-helper candidates. Trigger on phrases like "audit for duplication", "find duplicated code", "what can I deduplicate", "DRY this codebase", "find shared helpers", "look for copy-paste", "refactor candidates", or "is there repeated logic". Also trigger when the user scopes the request to a subset of the codebase (e.g., "only backend", "only hooks", "only tests", "just the API layer").
---

# Audit Duplicates

Deeply analyze the codebase for duplicated functions, utilities, and code patterns that should be extracted into shared helpers.

## Scope

If the user specified a scope (e.g., "only backend", "only hooks", "only tests", "just the worker code"), limit the search to the relevant directories. If no scope is given, analyze the entire codebase.

## What to look for

Search across all source files for:

- Repeated utility functions (string formatting, date handling, validation, data transformations)
- Duplicated database/API query patterns
- Similar React component structures, hooks, or render patterns
- Copy-pasted validation schemas (Zod, Yup, etc.)
- Repeated business logic across modules
- Constants or config values defined in multiple places
- Similar error handling or logging patterns
- Duplicated test setup/helpers

## Rules for flagging

Only flag genuine duplication — code that actually does the same thing in two or more places. Similar-looking code that serves different purposes is not duplication; don't flag it.

Standard patterns don't count. Every file importing the same utility isn't duplication — that's correct usage. Flag the definition, not the consumption.

Minimum threshold: code must appear in at least 2 files to be flagged.

Prefer showing the actual duplicated code snippets so the user can verify before refactoring.

## For each finding, report

- **Priority**: HIGH, MEDIUM, or LOW
- **What**: Brief description of the duplicated logic
- **Where**: Exact file paths and line numbers of each occurrence
- **Why extract**: Why this duplication is problematic (maintenance burden, divergence risk, subtle drift between implementations, etc.)
- **Suggested location**: Where the shared helper should live (which package/directory)
- **Suggested API**: Function signature for the extracted helper

## Output format

Group findings by priority (HIGH, then MEDIUM, then LOW). Within each group, list findings in this exact format:

```
### [PRIORITY] Finding Title

**Duplicated in:**
- `path/to/file-a.ts` (lines X-Y)
- `path/to/file-b.ts` (lines X-Y)

**What it does:** One-line description of the duplicated logic.

**Suggested helper:**
\`\`\`
functionName(param1: Type, param2: Type): ReturnType
\`\`\`

**Where to put it:** `path/to/suggested/location.ts`

---
```

After listing all findings, provide a summary count at the bottom: `X HIGH, Y MEDIUM, Z LOW`.

## Why this format matters

The priority grouping lets the user tackle the highest-leverage refactors first — HIGH items are ones where divergence between copies will cause bugs, MEDIUM are maintenance wins, LOW are nice-to-haves. The exact file paths and line numbers make the findings actionable; without them, the user has to re-hunt the duplication themselves, which defeats the purpose of the audit.
