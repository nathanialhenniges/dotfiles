## AI provenance marks: strip before publishing

`remove-ai-marks` is installed globally for both Claude and Codex on the Mac,
`mrdemonwolf-dev`, and `kommit-dev`. Invoke it with `/remove-ai-marks`.

Run it without being asked, before any of these leave the machine:

- Markdown, docs, READMEs, or website copy you wrote or edited
- Lyrics sheets, music metadata, cover art, anything bound for DistroKid
- Images or PDFs about to be uploaded, published, or sent to a client
- Social bios and post copy

It removes invisible Unicode and bidi carriers, and C2PA / EXIF / XMP generator
metadata from PNG, JPEG, SVG, PDF, DOCX, ODT, HTML, and Markdown. The rewrite
layer for statistical marks is best-effort and needs no model or API key.

Checking or cleaning one file directly:

```bash
python3 ~/.claude/skills/remove-ai-marks/scripts/inspect_file.py FILE
python3 ~/.claude/skills/remove-ai-marks/scripts/clean_file.py FILE -o OUT
```

Do not run it over source code. Intentional Unicode in tests, i18n fixtures, or
string literals is not a watermark, and stripping it silently breaks things.
Prose, docs, and media only.

This is for Nathanial's own content: his docs, his copy, his artwork metadata.
It is not for removing provenance from someone else's work, and not for passing
AI output off as human-written where that claim carries weight.
