---
name: uiux-review
description: Run a full UI/UX review of a website, app screen, design, or frontend code against Nielsen Norman Group (NN/g) guidelines, producing a severity-ranked Markdown report where every finding cites NN/g research as evidence. Use this skill whenever the user asks for a UI/UX review, design review, usability audit, heuristic evaluation, accessibility check, typography/visual-hierarchy critique, or says things like "review my site", "audit this page", "what's wrong with this design", "is this usable", "check my landing page", or mentions Nielsen Norman, NN/g, or usability heuristics — even if they don't say the word "review". Works on live URLs, screenshots, local frontend code (HTML/CSS/React/WordPress/Divi), and Figma links.
---

# UI/UX Review (NN/g Methodology)

Perform an evidence-backed UI/UX review. Every finding must (a) map to a Nielsen Norman Group guideline, (b) cite a real NN/g article fetched via web research, and (c) carry an NN/g severity rating. The output is one severity-ranked Markdown report.

## Step 1: Determine the input type

Supported inputs:

1. **Live URL** — fetch the page HTML and linked CSS
2. **Screenshot/image** — visual inspection
3. **Local code** — HTML/CSS/React/Vue/WordPress/Divi theme files
4. **Figma/design link** — visual inspection of exported frames or screenshots

If the user gave a URL, file, or image, proceed with it. If the request is ambiguous (e.g., "review my checkout flow" with nothing attached), ask ONE question: which input they want to provide. Do not ask if the input is already obvious.

Multiple inputs are better than one. If reviewing a live URL whose content is mostly JavaScript-rendered (fetched HTML is sparse or empty), say so and ask for a screenshot to supplement — don't guess at what the rendered page looks like.

## Step 2: Gather the artifact

- **Live URL**: Fetch the page. Then fetch the main stylesheet(s) referenced in `<link rel="stylesheet">`. From the HTML extract: heading structure (h1–h6 order and count), landmark/semantic elements, form markup, image alt attributes, link/button text. From the CSS extract: font sizes, line heights, color pairs (foreground/background), focus styles, breakpoints.
- **Screenshot**: Inspect visually for hierarchy, contrast, spacing, alignment, density, touch-target size relative to the viewport.
- **Code**: Read the actual files. For React, trace the rendered output (component → JSX → headings/labels). For WordPress/Divi, check theme CSS and template heading usage.
- **Figma**: Treat like a screenshot. Note that hover/focus/error states usually aren't visible — flag them as "unverifiable" rather than assuming they're missing.

Be honest about what each input type can and cannot verify. A screenshot can't prove keyboard focus styles are missing; static HTML can't prove a loading state exists. Mark such items **Unverified** in the report instead of inventing findings.

## Step 3: Review against the checklist

Read `references/nng-checklist.md` and walk every section that applies to the input type. The checklist covers:

1. The 10 usability heuristics
2. Typography & visual hierarchy (heading order, font sizes, line length/height)
3. Accessibility (contrast ratios, touch targets, alt text, focus states)
4. Layout, navigation & information architecture
5. Forms & error handling
6. Content & readability
7. Mobile/responsive

For measurable items, measure — don't eyeball. Pull the actual `font-size` values from CSS and compare heading levels numerically. Compute contrast ratios from actual hex values (the checklist includes the formula). A claim like "the h3 is larger than the h2" must come with the real values: "h2 is 20px, h3 is 24px".

## Step 4: Web research for evidence

Every finding cites a specific NN/g article. The checklist lists canonical nngroup.com article URLs per topic — fetch the relevant article(s) for the findings you have, confirm the guideline says what you're claiming, and cite it by title + URL. Paraphrase the guideline in your own words; do not quote more than a short phrase.

If a finding has no NN/g source, either:
- search the web for one (`site:nngroup.com <topic>`), or
- cite a WCAG success criterion instead (acceptable for accessibility-only items), or
- drop the finding into a "Reviewer judgment (no NN/g citation)" subsection so evidence-backed and opinion items never mix.

Never fabricate an article title or URL. A fake citation is worse than no citation.

## Step 5: Rate severity (NN/g 0–4 scale)

Use Nielsen's published severity ratings:

| Rating | Label | Meaning |
|---|---|---|
| 4 | Catastrophic | Blocks task completion; fix before release |
| 3 | Major | Significantly impedes users; high priority |
| 2 | Minor | Annoys or slows users; low priority |
| 1 | Cosmetic | Fix only if spare time |
| 0 | Not a problem | Don't list these as findings |

Severity = impact × frequency × persistence. A tiny font on the primary CTA is a 3; the same font in the footer copyright line is a 1. Justify any 3 or 4 in one sentence.

## Step 6: Write the report

ALWAYS use this exact structure:

```markdown
# UI/UX Review: [target name]

**Reviewed:** [date] · **Input:** [URL / screenshot / code / Figma] · **Method:** NN/g heuristic evaluation + guideline review

## Executive summary
[3–5 bullets: overall impression, the single worst problem, count of findings by severity]

**Findings:** 🟥 [n] catastrophic · 🟧 [n] major · 🟨 [n] minor · ⬜ [n] cosmetic

## Findings

### 🟥 Severity 4 — Catastrophic
#### 1. [Short finding title]
- **What:** [the problem, with measured values where applicable]
- **Where:** [page/element/selector/screen region]
- **Guideline:** [NN/g principle violated, e.g., "Visual Hierarchy — heading sizes must descend with level"]
- **Evidence:** [Article Title](https://www.nngroup.com/articles/...) — [one-sentence paraphrase]
- **Fix:**
  - [ ] [concrete step]
  - [ ] [concrete step]

### 🟧 Severity 3 — Major
[same format]

### 🟨 Severity 2 — Minor
[same format]

### ⬜ Severity 1 — Cosmetic
[same format, can be terser]

## Unverified (needs a different input to check)
- [item] — why it can't be verified from this input

## What's working well
[2–4 bullets — genuine strengths, not filler]

## Quick wins
- [ ] [highest-impact fixes doable in under an hour, pulled from findings above]
```

Rules for the report:
- Number findings sequentially across all severities so they're referenceable ("finding #7").
- Every Fix is a checkbox list of concrete actions ("change `h1` from 24px to 36px"), never vague advice ("improve hierarchy").
- Omit empty severity sections.
- If there are zero severity 3–4 findings, say so explicitly in the summary — that's a meaningful result.
- Save the report as a Markdown file and give it to the user; don't only paste it into chat.

## Quality bar

A reviewer reading this report should be able to verify every finding themselves: the location is specific, the measurement is stated, and the citation actually supports the claim. If a finding wouldn't survive the author of the page replying "prove it" — cut it or mark it Unverified.
