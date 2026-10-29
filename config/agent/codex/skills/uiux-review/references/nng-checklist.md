# NN/g Review Checklist

Walk every applicable section. For each item: check it, measure it if measurable, and note pass/fail/unverified. Article URLs below are the canonical citation sources — fetch the relevant one before citing it (titles and slugs occasionally change; if a URL 404s, search `site:nngroup.com <topic>`).

---

## 1. The 10 Usability Heuristics

Source: [10 Usability Heuristics for User Interface Design](https://www.nngroup.com/articles/ten-usability-heuristics/)
Severity scale source: [How to Rate the Severity of Usability Problems](https://www.nngroup.com/articles/how-to-rate-the-severity-of-usability-problems/)

| # | Heuristic | What to check |
|---|---|---|
| 1 | Visibility of system status | Loading states, progress indicators, active-nav highlighting, hover/pressed states, confirmation after actions |
| 2 | Match between system and real world | Jargon-free labels, familiar icons, logical ordering, real-world metaphors |
| 3 | User control and freedom | Undo/cancel available, back button works, no forced flows, easy exit from modals |
| 4 | Consistency and standards | Same action = same label everywhere; follows platform/web conventions (logo links home, links look like links) |
| 5 | Error prevention | Confirmation for destructive actions, constraints on inputs, sensible defaults |
| 6 | Recognition rather than recall | Visible options instead of memorized commands, contextual help, autocomplete |
| 7 | Flexibility and efficiency | Shortcuts for experts, recently-used items, sensible tab order |
| 8 | Aesthetic and minimalist design | No content that competes with the primary task; every element earns its place |
| 9 | Help users recognize/recover from errors | Plain-language error messages that say what went wrong and how to fix it |
| 10 | Help and documentation | Findable help, searchable, task-focused |

Heuristics 1, 3, 5, 7, 9 are often **Unverified** from screenshots/static HTML — flag, don't guess.

---

## 2. Typography & Visual Hierarchy

Sources:
- [Visual Hierarchy in UX: Definition](https://www.nngroup.com/articles/visual-hierarchy-ux-definition/)
- [Typography Terms Cheat Sheet](https://www.nngroup.com/articles/typography-terms-ux/)
- [How Users Read on the Web](https://www.nngroup.com/articles/how-users-read-on-the-web/)
- [F-Shaped Pattern of Reading on the Web](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/)
- [Legibility, Readability, and Comprehension](https://www.nngroup.com/articles/legibility-readability-comprehension/)

Checks (measure, don't eyeball):

- **Heading size order**: font sizes must descend with heading level. h1 > h2 > h3 > h4. Pull actual values from CSS. An h3 rendered larger than its h2 is a hierarchy violation (typically severity 2–3 depending on placement).
- **Heading level order in markup**: no skipped levels (h1 → h3 with no h2); exactly one h1 per page/view.
- **Headings used for structure, not styling**: a heading tag chosen "because it looked right" rather than for document outline.
- **Body font size**: ≥ 16px on web is the safe default; below 14px is a finding.
- **Line length**: 50–75 characters per line for body text. Estimate: container width ÷ (font-size × 0.5).
- **Line height**: body text ~1.5; below 1.2 hurts readability.
- **Font count**: more than 2–3 typefaces signals inconsistency.
- **All-caps body text, long italic passages, justified text with rivers**: legibility findings.
- **Scannability**: front-loaded headings, short paragraphs, bulleted lists where appropriate (F-pattern research).
- **Emphasis hierarchy**: size, weight, and color used consistently to signal importance; no two elements competing to be "loudest".

---

## 3. Accessibility

Sources:
- [Low-Contrast Text Is Not the Answer](https://www.nngroup.com/articles/low-contrast/)
- [Touch Targets on Touchscreens](https://www.nngroup.com/articles/touch-target-size/)
- WCAG 2.2 (cite specific success criteria when no NN/g article fits)

Checks:

- **Text contrast** — compute it from actual hex values:
  1. For each channel c in {R,G,B} as 0–1: if c ≤ 0.03928, c' = c/12.92, else c' = ((c+0.055)/1.055)^2.4
  2. L = 0.2126·R' + 0.7152·G' + 0.0722·B'
  3. Ratio = (L_lighter + 0.05) / (L_darker + 0.05)
  - Thresholds (WCAG AA): ≥ 4.5:1 normal text; ≥ 3:1 large text (≥24px, or ≥18.66px bold); ≥ 3:1 for UI components/icons.
  - Write a quick script for this rather than computing by hand when there are multiple pairs.
- **Touch targets**: ~1cm² (≈44–48px) for primary targets; WCAG 2.5.8 hard floor is 24×24px. Check buttons, nav links, icon buttons, form controls.
- **Alt text**: every meaningful `<img>` has descriptive `alt`; decorative images have `alt=""`.
- **Focus visibility**: `:focus`/`:focus-visible` styles exist and aren't `outline: none` with no replacement.
- **Link/button semantics**: links navigate, buttons act; no `<div onclick>` controls; link text meaningful out of context (no bare "click here").
- **Form labels**: every input has a programmatic `<label>` (placeholder is not a label).
- **Color not sole carrier of meaning**: errors/states also signaled by text or icon.
- **Motion**: autoplaying carousels/video have pause controls.

---

## 4. Layout, Navigation & Information Architecture

Sources:
- [Top 10 Web Design Mistakes](https://www.nngroup.com/articles/top-10-mistakes-web-design/)
- [Scrolling and Attention](https://www.nngroup.com/articles/scrolling-and-attention/)
- [Breadcrumbs: 11 Design Guidelines](https://www.nngroup.com/articles/breadcrumbs/)

Checks:

- Primary action visible without scrolling on the entry viewport; most important content prioritized (attention drops sharply down-page).
- Current location indicated (active nav state, breadcrumbs on deep hierarchies).
- Nav labels are descriptive, mutually exclusive, ≤ 7±2 top-level items as a soft signal (use judgment).
- Logo links to home; search is findable on content-heavy sites.
- Consistent grid/alignment; spacing groups related items (proximity); no false groupings.
- No content mimicking ads ("banner blindness" zones for key content).
- Clickable things look clickable; non-clickable things don't.

---

## 5. Forms & Error Handling

Sources:
- [Website Forms Usability: Top 10 Recommendations](https://www.nngroup.com/articles/web-form-design/)
- [Error Message Guidelines](https://www.nngroup.com/articles/error-message-guidelines/)

Checks:

- Only necessary fields; optional fields marked (or required marked, consistently — pick one).
- Single-column layout for forms; logical grouping; label above or beside field, visible at all times.
- Inline validation where it helps; error messages adjacent to the field, in plain language, stating the fix.
- Submit button labels describe the action ("Create account", not "Submit").
- Input types match data (email, tel, number keyboards on mobile).
- Destructive/irreversible actions require confirmation.

---

## 6. Content & Readability

Sources:
- [How Users Read on the Web](https://www.nngroup.com/articles/how-users-read-on-the-web/)
- [F-Shaped Pattern of Reading on the Web](https://www.nngroup.com/articles/f-shaped-pattern-reading-web-content/)

Checks:

- Page title/h1 states what the page is for in user language.
- First two paragraphs carry the key message (front-loading).
- Microcopy: button/link labels predict what happens next.
- No walls of text; one idea per paragraph; objective tone over promotional fluff.

---

## 7. Mobile / Responsive

Sources:
- [Touch Targets on Touchscreens](https://www.nngroup.com/articles/touch-target-size/)
- [Scrolling and Attention](https://www.nngroup.com/articles/scrolling-and-attention/)

Checks (when input allows — responsive CSS in code, or a mobile screenshot):

- Viewport meta tag present; no horizontal scroll at mobile widths.
- Breakpoints exist; layout reflows rather than shrinking.
- Font sizes don't drop below 16px body at mobile breakpoints (also prevents iOS zoom-on-focus for inputs).
- Tap targets adequately spaced; thumb-reachable primary actions.
- Hover-only interactions have touch equivalents.

---

## Input-type capability map

| Check area | Live URL (HTML+CSS) | Screenshot | Code | Figma |
|---|---|---|---|---|
| Heading markup order | ✅ | ❌ (visual sizes only) | ✅ | ❌ |
| Font sizes / line height | ✅ (from CSS) | ~ (estimate) | ✅ | ~ |
| Contrast ratios | ✅ (from CSS) | ~ (sample colors) | ✅ | ~ |
| Alt text / labels / semantics | ✅ | ❌ | ✅ | ❌ |
| Focus states | ✅ (CSS) | ❌ | ✅ | ❌ |
| Hover/loading/error states | ❌ | ❌ | ~ | ~ |
| Visual hierarchy / layout | ~ (inferred) | ✅ | ~ | ✅ |
| Responsive behavior | ~ (media queries) | only the shown width | ✅ | ❌ |

✅ verifiable · ~ partially · ❌ mark as Unverified
