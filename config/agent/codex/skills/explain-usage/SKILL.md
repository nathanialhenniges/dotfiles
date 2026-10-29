---
name: explain-usage
description: "Explain Codex account limits or measured context consumption when the user asks about usage."
---

# explain-usage

For account limits use get_usage_limits. Interpret usedPercent as consumed, remaining as max(0, 100-usedPercent), and reset times in the user's timezone. Prefer rateLimitsByLimitId; missing data means unavailable.
For context savings use Context Mode's stats tool. Display full stats when the user invokes ctx stats.
For a requested local breakdown, aggregate relevant session records without printing secrets or private connector content. Label estimates; transcript length does not prove billing or internal prompt sizes.
Do not use Claude transcript paths or confuse session measurements with account-wide usage.
