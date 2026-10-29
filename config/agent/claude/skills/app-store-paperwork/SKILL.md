---
name: app-store-paperwork
description: >-
  Inventory an app's App Store and Play paperwork (privacy policy, privacy
  labels, screenshots, review notes, subscriptions, encryption export, appeal
  letters), report what is done, and file Jira tickets for the gaps when asked.
---

# app-store-paperwork

Use for "how much store paperwork is done", release prep, or turning missing store items into Jira tickets. Pair with $app-store-review-audit when the question is whether review will pass.

## Checklist

Check each item against the repo, then mark it DONE, PARTIAL, MISSING or UNKNOWN with evidence (file path, config key, or store record).

1. **Privacy policy page**: a public URL that describes what the app and its backends actually collect. Compare it with the code, analytics, crash reporting and any live forms.
2. **App Privacy labels / Play Data safety**: answers derived from the code. Keep a source-of-truth file in the repo, for example `docs/store/privacy-labels.md`, listing each data type, purpose, linkage and tracking.
3. **Screenshots**: the sizes each store currently requires. Check current Apple and Google requirements from official docs, not memory. Store sources under a versioned folder such as `docs/store/screenshots/`.
4. **Review notes**: one file per version, for example `docs/store/review-notes-<version>.txt`. Cover demo data or login, how to reach every feature, and anything that needs explaining.
5. **What's new text**: one file per version and locale, such as `docs/store/whats-new-<version>.txt`.
6. **Subscriptions and purchases**: groups, product IDs, prices, intro offers, restore flow, and the entitlement names the code checks. Mark not-applicable if the release is free.
7. **Encryption export**: the `ITSAppUsesNonExemptEncryption` answer or an Expo `usesNonExemptEncryption` value, and why.
8. **Appeal / rejection letters**: keep a template plus each sent reply under `docs/store/appeals/`.

## Rules

- Read repo instructions first. Release docs such as `RELEASING.md` win over this list.
- Never invent store state. App Store Connect and Play Console values are UNKNOWN unless a connected tool or the user shows them.
- Only write Jira tickets when the user asks. Confirm the project key and labels first, check for duplicates, and give each ticket a problem, acceptance checks and evidence.
- Never put secrets, real emails, auth codes or unpublished data in tickets or files.
- Finish with a short table: item, status, evidence, next step.
