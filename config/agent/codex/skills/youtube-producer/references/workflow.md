# YouTube episode workflow

## Current show formats

Use the current Notion **Content Guide** and show README/publishing kit for exact rules only when Nathanial chooses that show. Wolf Standup is a weekly vertical talking-head Short; The Monthly Bark is a monthly horizontal long-form show. Those are distinct show formats, not default templates for every video. Start from the video Nathanial describes, then choose its structure, pacing, length, visuals, and deliverables to fit. Do not force a Short into a long-form outline or a long-form video into a Short's beats. Treat the guides' specifics as show-specific; other ideas get their own fit-for-purpose plan. Older notes about Open Tabs Tuesday, a bi-weekly show, or a 60–90 second standup are historical ideas, not current formats.

Current Notion timing: Wolf Standup record Monday 2:30–3:30pm, reset 3:30–4:00pm, edit/export/schedule 4:00–5:00pm, intended YouTube publication Tuesday 1:00pm CT, cross-post Tuesday 3:30–4:00pm. The Monthly Bark: write/record first Thursday 9:00–10:30am, The Den co-working 11:00am–3:00pm, edit/export/schedule 7:00–9:00pm, intended YouTube publication following Friday 1:00pm CT, cross-post 1:15–1:45pm. Notion and the current show files outrank old master-pack cadence.

Every video plan also names its **Video type**: **Short (9:16)** or **Long-form (16:9)**. The show name alone is not a substitute.

## Start with enough context

Accept messy notes and ask a compact set of questions, skipping anything already clear:

1. What is the video idea?
2. Is it a Short (9:16), a regular video (16:9), or should I recommend?
3. What should the viewer learn, feel, or do?
4. How will you record it (Mobbin on iPhone, OBS, screen capture, webcam, or another way)?

Ask about the audience, tone, key example, timing, and call to action only when useful. Ask one question at a time if Nathanial seems unsure. State any assumptions in the draft and keep working in the same reply unless one missing choice blocks the plan. Before thumbnail generation, request an actual frame, snoot/sona reference, product image, or screenshot. If he has none, help identify what to capture and continue the script/flow work; don't invent a visual.

## Keep the work small

- Use the intake above to capture topic, type, viewer payoff, and recording path. Ask for a date only when planning a schedule. Do not require a named show if the idea can be planned without one.
- Draft one complete, editable run sheet from the idea. Put the hook/script and next action first; group recording, visual, Final Cut Pro, title/description, thumbnail, folder, and Notion details below so Nathanial does not have to build the package himself.
- Offer alternatives only where a choice materially changes the episode. Ask one focused question only when a missing answer blocks a useful plan; otherwise make a clear, editable recommendation.
- Make the script structure fit this idea. A Short needs a concise hook and a few spoken beats; long-form needs a clear opening, useful sections and examples, and an ending. Do not force show templates onto unrelated videos.
- Include the complete YouTube package by default: spoken script, one recommended title and up to two alternatives, exact unique description, relevant comma-separated tags, primary/related keyword phrases, three distinct thumbnail ideas, an optional supplied-image choice, and the selected finished thumbnail after Nathanial chooses, and recording/edit steps. Ask focused questions and revise the package together; use chapter ideas without invented timestamps until the real edit exists. Titles must be accurate and under 100 characters; descriptions must be under 5,000 characters. Do not promise rankings or stuff keywords.
- Make the final upload checklist easy to scan: title, description, selected thumbnail or Shorts frame, captions, audience setting, and visibility/schedule. Ask Nathanial to choose audience and visibility when context does not answer them; never assume or publish for him. Tags and playlists are optional. Follow [YouTube title and thumbnail tips](https://support.google.com/youtube/answer/12340300) and [description tips](https://support.google.com/youtube/answer/12948449).
- Do not add capture-only test clips to Notion as episodes. Start a card when there is a real idea and Nathanial approves its title and type; include a show when he chooses one.
- Keep an episode's current state visible: Idea → Ready to record → Ready to edit → Editing → Edited → Exported → Uploaded / Scheduled.
- Use the local project's episode template if available. Do not duplicate source-of-truth guidance into a second database or parallel document unnecessarily.

## Media handoff

Mobbin is Nathanial's iPhone VTuber recording app. AirDrop recordings arrive in `~/Downloads`; OBS recordings are saved under `~/Movies`. Preserve the original filenames. On Nathanial's Mac, the current recording destinations are:

```text
~/Movies/Recordings/Mobbin/
~/Movies/Recordings/OBS/
```

The October 20 local workflow notes record active Forel rules for matching iPhone recordings and Mac mini OBS recordings. Dummy routing passed; real video playback and the full edit/export round trip remain unverified. ChatGPT Web cannot inspect the current watcher or move Mac files. The local layout for any video type uses its date and title:

```text
YouTube/
└── 2026/
    └── 2026-10-20-your-video-title/
        ├── your-video-title.fcpbundle
        └── Publish/
            ├── your-video-title.mp4
            ├── thumbnail.png
            ├── captions.srt (only when available)
            └── upload-kit.pdf
```

The local base is `~/Movies/Final Cut Projects/YouTube`. Import selected takes using Copy to Library and retain the originals in their recording folders until a complete Drive backup is verified. Drive uses `Editing` for closed editing-library backups, `To Upload` for ready upload files, and `Uploaded` for the completed library plus Publish assets, each under year/date-video-title. Existing Thumbnails and channel banner remain. Follow the final ZIP/PDF checklist in SKILL.md; Forel routes only matching Mobbin filenames to the general Mobbin Recordings folder and cannot select an episode.

The iPhone sample filename `Recording_2026-10-19_031354.mp4` shows the pattern `Recording_YYYY-MM-DD_HHMMSS.mp4`. It was shared to demonstrate the filename format, not as an episode or a broken transfer.

OBS's current global filename format is `%CCYY-%MM-%DD %hh-%mm-%ss`; it applies across OBS profiles and names files with the date and time. The agreed destination is `~/Movies/Recordings/OBS/`, with no `Raw` folder or year/month/day subfolders. Nathanial will set the recording path in OBS himself; do not claim it has been configured. Import selected compatible takes into the local library.

The Mac currently has OBS 32.2.2. Recommended recording container is **Hybrid MOV** with Apple VT H.264 for easier Final Cut Pro handoff and crash recovery; automatic remux should stay off with Hybrid MOV. Make one short test and confirm the mic and desktop tracks arrive in Final Cut Pro. If Hybrid MOV is unavailable or the audio tracks do not work as expected, choose MKV and enable automatic remux to MP4. Do not claim the active format was verified from the saved profile: its recording encoder JSON was absent.

Prefab is installed with a tested YouTube Video Project template, available through Finder’s New Folder(s) from Template menu. It creates local date/title folders only. After closing Final Cut Pro, `yt-video-backup '<year>/<date-video-title>'` from Nathanial's dotfiles copies the whole project to `My Drive/MultiMedia Projects/Social Media/YouTube/Editing/<year>/` and checks the local copy; Drive sync and remote visibility require a separate check. The command refuses to replace an existing backup. Forel cannot identify the active episode, so Nathanial selects the takes. Do not change OBS paths or move source footage without instruction.

## Final Cut Pro handoff

- Create/open the episode project from the existing YouTube template.
- Import chosen originals with Copy to Library; retain source files until the full archive is verified.
- Use Textream (already installed) as the teleprompter; edit and prepare captions in Final Cut Pro or another actually available caption tool.
- Export the requested aspect ratio and resolution; do not invent export settings when the project/template specifies them.
- Record the final export location in the episode handoff.

## Thumbnail concepts for both formats

Start from the episode's actual point and Nathanial's supplied screenshots/photos, not a generic creator-thumbnail formula. Concepts can be discussed without references, but before generating finished thumbnail art ask for a real episode frame/snoot, authentic screenshot/product image, or an explicit okay to use only the bundled approved wolf artwork. Make up to three separate candidates in the selected format: 16:9 for regular video, 9:16 for Shorts. Never make a generated lookalike UI.

- **Opinion / reaction:** expressive approved blue-wolf reference + one real topic object + clear headline block.
- **Tutorial / tech:** authentic screen or product image as the main image + smaller wolf crop.
- **Monthly / ranking:** feature one result, tier, or item + wolf reaction; avoid dense grids and collages.

Use Brand Navy `#0A1633` and Sky Blue `#3AAEE3`, readable contrast, and a single focal point. Keep the approved artwork intact and undistorted. Generate separate artwork without text; place exact headline text in an editor so spelling and layout stay controlled. Label each image with its composition, reason, and separate 2–4 word headline suggestion. Do not use AI-looking gradients, excess glow, random decorative icons, fake screenshots, or invented logos. If image generation is unavailable, provide concepts and prompts instead of claiming images were created.

For a 16:9 video thumbnail use the publishing kit's 3840×2160 export; for vertical Shorts cover art use its 2160×3840 canvas. Current YouTube help says custom Shorts thumbnails can be uploaded in YouTube Studio on desktop for eligible, verified accounts, with 9:16 recommended. Check the current account/platform requirements before promising an upload workflow. When an image-generation tool is present and Nathanial asks for finished art, create the selected layout with the attached approved wolf reference and episode screenshots; don't stop at a prompt unless image generation is unavailable. For safe placement rules, use [thumbnail-directions.md](thumbnail-directions.md).

## Notion finalization

Notion is the source of truth for approved per-video content and status. PDF/ZIP exports are optional on request; keep the working draft readable in Chat and approved fields on the same existing episode card.

The current **YouTube Videos** board is under Creator → Content. Each card includes a **Video type** of Short or Long-form. Present one complete editable run sheet by default, with details grouped under short headings. Nathanial may approve the whole plan or individual sections in plain language. Save only the approved parts to the same Notion card when the Notion connection is available. Create the card after he approves its title and type. Keep unapproved drafts in ChatGPT; do not make him transfer text between apps. Approval of a specific thumbnail candidate authorizes uploading it to `My Drive/MultiMedia Projects/Social Media/YouTube/Thumbnails/<video-slug>/`; find the existing parent folder, create its video subfolder if needed, upload only that approved image, and put its Drive link on the card. Mark recording/editing steps complete only after he confirms them, and mark Published only after publication is confirmed. If Notion or Drive is unavailable, return the approved content or image locally and clearly say what was not saved.

## App decisions

| App | Use now? | Role |
|---|---|---|
| Textream | Yes | Teleprompter for the approved script; already installed. |
| Final Cut Pro | Yes | Main edit, reusing the existing YouTube template. |
| Prefab | Configured locally | Date/title template passed a temporary folder test; local folders only. |
| Forel | Configured locally | iPhone/Mac mini routing passed dummy-file tests; real video round trip remains unverified. |
| Clop | Optional | Image/video file compression only when a concrete file-size problem appears. |
| Other apps from the original shortlist | Not in the first workflow | Revisit only when a specific need appears. |

## Video-notes navigation

Start every Notion video card with a native table of contents. Use section headings so script, production, upload copy, thumbnail options and social posts are reachable directly. Keep the TOC first when adding later notes; add it to existing cards if missing without changing approved content or production state.

## Backup before upload handoff

Before presenting a video as ready to upload, verify its project/media backup in Drive Editing and final video plus approved thumbnail in Drive To Upload. Compare local checksums, then independently confirm remote file presence and sizes using Drive tools. A CloudStorage copy alone is not remote verification; claim remote checksum verification only when supported. If cloud access is unavailable, leave verification pending. Save observed Drive links and the verification level on the existing Notion card below its TOC, then give Nathanial the Drive video, thumbnail and Notion links. Direct Remotion videos back up source/media rather than a fabricated Final Cut library.

Descriptions use the approved Wolf Den footer in the channel guide beneath the video-specific opening and disclosures. Upload handoffs lead with local Google Drive To Upload paths for the MP4 and approved thumbnail, then the Notion upload-details link; cloud links are secondary backup references.
