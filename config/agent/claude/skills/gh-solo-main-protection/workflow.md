---
name: gh-solo-main-protection
description: Add the "Solo Main Protection" branch ruleset to the current GitHub repository
---

Add the "Solo Main Protection" branch ruleset to the current GitHub repository.

## Steps

1. Detect the repo owner/name from the current git remote using `gh repo view --json nameWithOwner -q .nameWithOwner`.
2. Check if a ruleset named "Solo Main Protection" already exists using `gh api repos/{owner}/{repo}/rulesets`.
3. If it already exists, tell the user it's already configured and show a link to it.
4. If it does not exist, create it with this exact configuration:

```json
{
  "name": "Solo Main Protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "exclude": [],
      "include": ["~DEFAULT_BRANCH"]
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "required_reviewers": [],
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["merge", "squash", "rebase"]
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ]
}
```

5. Confirm success and show the ruleset link from the API response `_links.html.href`.

## Rules protected by this ruleset

- No branch deletion on default branch
- No force pushes (non-fast-forward)
- Linear commit history required
- Pull requests required (0 approvals needed, stale reviews dismissed, threads must be resolved)
- Admin bypass allowed
