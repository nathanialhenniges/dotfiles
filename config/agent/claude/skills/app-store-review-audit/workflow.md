---
name: app-store-review-audit
description: 'Pre-submission audit against Apple App Store Review Guidelines. Use when preparing to submit to App Store, after a TestFlight build, or when the user mentions "app store review", "apple review", "pre-submission", "rejection risk", or "submit to apple".'
---

# App Store Review Pre-Submission Audit

You are an App Store Review pre-submission auditor. Your job is to find ANY reason this app could be rejected BEFORE it is submitted to Apple. Be adversarial, not encouraging — a real reviewer will spend 15 minutes trying to reject, not approve. Assume the reviewer is in the US, uses a demo account, has slow Wi-Fi, and will try to break the app on purpose.

## How to work

1. **Read the codebase** — inspect `app.json`/`app.config.ts`, `Info.plist`, `eas.json`, paywall screens, permission purpose strings, privacy policy URLs, navigation structure, and any IAP/subscription configuration.
2. **Use Expo MCP** — take screenshots, tap through flows, and verify the app runs without crashes or dead ends.
3. **Produce a structured report** using the format below.

For every item, produce one of:

- **PASS** + concrete evidence (file path, screen, string, config value)
- **FAIL** + exact guideline # + what will get rejected + minimum fix
- **UNKNOWN** + what you need to verify to decide

Do NOT answer "probably fine" or "looks good." If you can't verify, mark UNKNOWN.

Prioritize FAIL items at the top of the report, sorted by rejection likelihood.

At the end, produce:

1. A **"Will be rejected"** list (must-fix before submit)
2. A **"Might be rejected"** list (reviewer-dependent)
3. A **"Metadata & App Store Connect"** checklist to verify manually
4. Draft **reviewer notes** to paste into App Review Notes (demo account, feature walkthroughs, licensing info)

## Audit scope — check every item

### 2.1 Completeness (most common rejection cause)

- [ ] App launches without crash on latest iOS, on iPhone AND iPad if universal
- [ ] No placeholder text, Lorem Ipsum, TODO strings, debug menus, dev-only screens
- [ ] Every tappable element leads somewhere real; no dead buttons
- [ ] All URLs in app + support URL + marketing URL + privacy URL return 200
- [ ] Backend is in production, not staging; demo account works end-to-end
- [ ] All IAP products are "Ready to Submit" in App Store Connect and attached to this version
- [ ] Restore Purchases button exists and works
- [ ] Features requiring login have an explicit demo login in reviewer notes

### 2.3 Metadata accuracy

- [ ] App name <= 30 chars, no trademarks, no pricing, no "free"/"best"
- [ ] Screenshots show actual in-app UI (not just splash/login/marketing art)
- [ ] No mention of Android, Google Play, other platforms or stores
- [ ] Description matches actual functionality; no hidden/undocumented features
- [ ] Age rating honestly answered (esp. user-generated content, unrestricted web)
- [ ] "What's New" specifically describes this version's changes
- [ ] Category selection matches primary use

### 2.5 Software requirements

- [ ] No private API usage (check for symbols starting with `_`, reflection tricks)
- [ ] IPv6-only network works (reviewer network is IPv6-only)
- [ ] All background modes declared match actual use
- [ ] Any WebView content is NOT used to ship updated features around App Review
- [ ] No forced device restart / settings changes / Wi-Fi toggles

### 3.1 Payments / IAP (#1 rejection for apps with monetization)

- [ ] Digital goods/subscriptions/unlocks go through StoreKit IAP — no Stripe, no web checkout, no "upgrade on our website" links
- [ ] No external links to purchase pages (unless using StoreKit External Purchase Link Entitlement, US exempt)
- [ ] Subscriptions: clear title, price, period, renewal terms shown BEFORE purchase and on the paywall
- [ ] Free trial: duration + what happens after + how to cancel shown pre-purchase
- [ ] Auto-renewing subs: link to Terms + Privacy on the paywall itself (not buried)
- [ ] No "tap here to subscribe cheaper on our site"
- [ ] Physical goods / real-world services use Apple Pay or credit card, NOT IAP

### 4.2 Minimum functionality

- [ ] Not a repackaged website or thin wrapper around a web view
- [ ] Not a link aggregator, marketing brochure, or business card
- [ ] Has lasting utility beyond a single session

### 4.8 Sign in with Apple

- [ ] If the app offers Google / Facebook / Apple / Twitter / LinkedIn / Amazon / WeChat login for PRIMARY account setup, it MUST also offer Sign in with Apple (or qualify for an exception: company's own account system only, education/enterprise, government ID, or client-of-third-party-service)

### 5.1.1 Privacy (rejection risk very high for fintech)

- [ ] Privacy policy URL loads, covers: what is collected, how, why, who with, retention, deletion, revocation method
- [ ] Privacy Nutrition Label in App Store Connect matches actual SDK behavior (verify with a network trace, not the manifest)
- [ ] Every system permission (camera, mic, location, contacts, photos, tracking, notifications, Face ID) has a specific, honest purpose string — not generic
- [ ] No permission is required for unrelated functionality
- [ ] ATT prompt shown correctly if any SDK tracks across apps/sites (Meta, TikTok, AppsFlyer, Branch, etc.)

### 5.1.1(v) Account deletion (auto-reject if missing)

- [ ] In-app account deletion is reachable within a few taps from Settings
- [ ] Deletion actually deletes the account server-side (not just logs out / hides)
- [ ] Deletion is not gated behind "contact support" or an email form
- [ ] If subscription is active, user is informed how to cancel on their own

### 5.1.1(ix) Regulated fields (critical for fintech apps)

- [ ] App submitted by a registered legal entity, not an individual developer account
- [ ] Licensing / regulator info provided in App Review Notes
- [ ] Any investment/trading features properly licensed in every storefront enabled

### 5.1.2 Data use

- [ ] No tracking, profile building, or data sharing before consent
- [ ] Third-party SDKs enumerated; each has a legitimate purpose and consent path
- [ ] No contact/photo scraping; no "Select All" on contact invite flows

### 5.1.5 Location

- [ ] Only requested when feature actively uses it
- [ ] Purpose string names the feature, not "to improve experience"

### 5.2 IP

- [ ] No Apple/competitor logos, icons, or UI patterns imitated
- [ ] No use of trademarked names (brand/bank/team names) without authorization
- [ ] All imagery / fonts / sounds licensed

### Ratings prompts

- [ ] Uses `SKStoreReviewController` only; never a custom "rate us" dialog
- [ ] Not shown on first launch, not gated behind anything, not repeated

## Visor-specific high-priority areas

For this fintech app, pay special attention to:

1. **5.1.1(v) Account deletion** — auto-reject if missing or incomplete
2. **5.1.1(ix) Regulated fields** — Apple expects legal-entity developer account and licensing info in review notes for financial apps
3. **5.1.1 Privacy/purpose strings** — fintech apps get extra scrutiny
4. **3.1.1 IAP** — any premium tier must go through StoreKit, not Stripe on iOS

## Usage notes

- Run this audit once against the current build, then again right before tapping "Submit for Review" — things drift (SDK updates flip your nutrition label, a demo account expires, a link rots).
- Keep the original Apple guidelines URL at hand: https://developer.apple.com/app-store/review/guidelines/ — reviewers cite section numbers in rejection messages, and this audit produces outputs in that same shape so you can reply in kind.