---
name: mrdw-readme
description: Generate a README.md in the MrDemonWolf house format — a specific section order (Title, Description, Features, Getting Started, Usage, Tech Stack, Development, Project Structure, License, Contact, Footer) with standard markdown only, no emojis, no HTML, a GitHub license badge linked to the mrdemonwolf GitHub org, a Discord invite at mrdwolf.net/discord, and a "Made with love by MrDemonWolf, Inc." footer. Use this skill whenever Nathanial asks to generate, create, write, draft, or update a README for any of his projects — MrDemonWolf, Inc. repos, open-source tools, personal projects, or client work he owns. Also trigger when he says "my readme format", "the MrDemonWolf readme style", "standard readme", "house readme", "readme template", or asks for docs/README for projects like FluffBoost, WolfWave, HowlBoard, FangDash, LinkDen, Community Bot, ConPaws, or the Official App. Trigger even when he doesn't explicitly name the format — if he's asking for a README and this is his codebase, use this skill.
---

# MrDemonWolf README Generator

Generate a README.md in the MrDemonWolf house format.

Before writing anything, read the project's source code, `package.json` (or equivalent manifest), and any existing docs so the README reflects actual values from the codebase. Don't guess at features, scripts, tech stack, or structure — use what's really there.

## Section order

Use this exact order. Omit sections that don't apply (e.g., no "Usage" tables for a library with no CLI) rather than padding them with placeholder content.

1. **Title** — `# Project Name - Short Tagline`
2. **Description** — 2-3 sentence paragraph explaining what the project does, who it's for, and why it exists. End with a motivational one-liner on its own line.
3. **Features** — Bulleted list with bold feature names and brief descriptions.
4. **Getting Started** — Link to full docs (if they exist), then a numbered list of quick-start steps.
5. **Usage** — Primary usage examples. For CLI tools, show commands. For apps with chat/commands (Discord bots, etc.), use tables grouped by role or category.
6. **Tech Stack** — Table with "Layer" and "Technology" columns.
7. **Development** — Four subsections in this order:
   - **Prerequisites** — Bulleted list of required tools/versions.
   - **Setup** — Numbered steps with code blocks for each command.
   - **Development Scripts** — Bulleted list of available scripts with descriptions (pull these from `package.json` scripts or equivalent).
   - **Code Quality** — Brief list of key tools/practices used.
8. **Project Structure** — Tree diagram of the top-level directory layout with inline comments.
9. **License** — GitHub license badge:
   ```
   ![GitHub license](https://img.shields.io/github/license/mrdemonwolf/<repo>.svg?style=for-the-badge&logo=github)
   ```
   Replace `<repo>` with the actual repository name.
10. **Contact** — Links for questions/feedback. Include at minimum:
    - Discord: `[Join my server](https://mrdwolf.net/discord)`
11. **Footer** — `Made with love by [MrDemonWolf, Inc.](https://www.mrdemonwolf.com)`

## Formatting rules

- Standard Markdown only. No HTML tags.
- Tables must have aligned columns using dashes and pipes.
- Code blocks use triple backticks with the language specified (e.g. ` ```bash `, ` ```ts `).
- Wrap prose around 70 characters per line where practical.
- **No emojis anywhere.** This is a hard rule — Nathanial's README style is deliberately clean and professional.
- Bold feature names in the Features section.
- Use `monospace` (single backticks) for commands, file paths, and variable names inline.

## Adaptations by project type

The section order above is the default. Adjust based on what the project actually is:

- **Libraries / npm packages**: Replace "Usage" with API examples and import instructions. Add an "Installation" section right after "Getting Started" showing the install command.
- **CLI tools**: Show command examples in "Usage" (not tables).
- **Web apps**: Include any relevant URLs, default ports, or browser instructions in "Usage" or "Getting Started".
- **Discord bots / chat apps**: Use tables in "Usage" grouped by command category or permission role.
- **Monorepos**: Show the workspace layout in "Project Structure" and list per-workspace scripts in "Development Scripts".

## Why this format

The section order front-loads what a visitor needs: what the project is, why they'd use it, and how to get it running. The license badge and contact block at the bottom are consistent across every MrDemonWolf repo so contributors always know where to find them. No-emojis and plain-markdown keep the README readable in terminal previews (`gh repo view`, `cat README.md`) and in environments that render markdown inconsistently.

## Example title and footer

For a project called "FluffBoost" — a Discord engagement bot:

```markdown
# FluffBoost - Motivation and Engagement for Your Discord Server

FluffBoost is a Discord bot that delivers scheduled motivational quotes,
engagement prompts, and community-boosting features to servers of any size.
Built for furry communities and beyond, it's trusted by 140+ Discord servers.

Keep your server active. Keep your community howling.
```

And the footer, verbatim:

```markdown
Made with love by [MrDemonWolf, Inc.](https://www.mrdemonwolf.com)
```
