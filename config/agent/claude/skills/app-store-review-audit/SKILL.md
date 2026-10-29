---
name: app-store-review-audit
description: Audit an iOS app's App Store submission readiness against review requirements.
---

# app-store-review-audit

When the preserved workflow conflicts with this entrypoint or current user and environment rules, follow this entrypoint and the active rules.

Read workflow.md for the preserved checklist. Verify current Apple guidelines from official sources before applying numbered requirements.
Inspect actual app, metadata, config, and available store records. Respect repo release gates.
Report PASS with evidence, FAIL with guideline and minimum fix, or UNKNOWN with needed verification. Separate static, automated, simulator/device, live-service, and signed-distribution evidence.
Cover completeness, metadata, purchases, authentication, privacy/deletion, regulated features, user content, accessibility, and reviewer notes. Do not assert inevitable rejection without evidence.
An audit does not authorize submission or publishing.
