# YouTube project backup: start to finish

This guide is for a Mac with Final Cut Pro and Google Drive for desktop. You
need one terminal command per video. It copies your edit folder to the mounted
Drive folder and checks the local copy. You then confirm the cloud upload.

## Contents

- [Quick checklist](#quick-checklist)
- [Where files go](#where-files-go)
- [Set up once](#set-up-once)
- [Try a dummy project](#try-a-dummy-project)
- [Back up a real video](#back-up-a-real-video)
- [Check the result](#check-the-result)
- [How it works](#how-it-works)
- [Common problems](#common-problems)
- [Run it with an AI agent](#run-it-with-an-ai-agent)

## Quick checklist

- [ ] Close Final Cut Pro, Motion, Logic Pro, and Compressor.
- [ ] Run `yt-video-backup '2026/2026-11-03-my-video'` with your actual folder name.
- [ ] Wait for **Local copy verified**.
- [ ] Wait for Google Drive to say **Up to date**.
- [ ] Check the library and exported video on Drive's website.

Keep your local originals until the last check is done.

## Where files go

```text
Your Mac
└── Movies/Final Cut Projects/YouTube/
    └── 2026/
        └── 2026-11-03-my-video/
            ├── My Video.fcpbundle    ← Final Cut library
            └── Publish/my-video.mp4  ← exported video

Google Drive for desktop
└── My Drive/MultiMedia Projects/Social Media/YouTube/
    └── Editing/2026/2026-11-03-my-video/  ← complete copy
```

The command copies **everything inside one project folder**. That folder
must be directly inside a four-digit year folder. Names may contain spaces;
keep the command argument in quotes.

## Set up once

### 1. Install the command

Clone this dotfiles repo. On macOS, preview and run its apply-only installer
from the repo root:

```bash
./install.sh --apply-only --dry-run
./install.sh --apply-only
```

It installs `~/.scripts/yt-video-backup`, the short alias, and the shell
config that reads `~/.secrets`. If you only want this one script, use:

```bash
mkdir -p "$HOME/.scripts"
install -m 755 config/.scripts/yt-video-backup "$HOME/.scripts/yt-video-backup"
```

With the one-script method, type `~/.scripts/yt-video-backup` in place of
the short alias unless you set up that alias separately.

### 2. Connect Drive

Install Google Drive for desktop, sign in, and confirm in Finder that this
folder exists inside **My Drive**:

```text
MultiMedia Projects/Social Media/YouTube
```

The script creates `Editing/<year>/` when needed. It does not create the
main `YouTube` folder, which helps catch a wrong account or location.

### 3. Add the private variable

Copy the line from the
[example file](../examples/yt-video-backup.env.example) into `~/.secrets`.
Replace the example account name with your `GoogleDrive-...` folder name from
`~/Library/CloudStorage/`. Stop **before** `/My Drive`:

```bash
export MEDIA_BACKUP_DRIVE="$HOME/Library/CloudStorage/GoogleDrive-your-account@example.com"
```

Never put your real account path in the example file or commit `~/.secrets`.
If you created `~/.secrets` just now, limit access to your user:

```bash
chmod 600 "$HOME/.secrets"
```

Open a new terminal. Check setup without printing the account path:

```bash
test -d "$MEDIA_BACKUP_DRIVE/My Drive/MultiMedia Projects/Social Media/YouTube" && echo 'Drive folder ready'
command -v yt-video-backup
```

The first line should print `Drive folder ready`. The second should find the
alias with the full dotfiles install. With the one-script install, check
`test -x "$HOME/.scripts/yt-video-backup"` instead, and load your variable
with `source "$HOME/.secrets"` in that terminal if your shell does not
already do so.

## Try a dummy project

This makes a tiny text-only test. It does **not** open your camera, mic, OBS,
or Final Cut Pro. Run these lines in order in a terminal with the private
variable loaded:

```bash
mkdir -p "$HOME/Movies/Final Cut Projects/YouTube/2026/backup-demo/Publish"
printf 'dummy backup test\n' > "$HOME/Movies/Final Cut Projects/YouTube/2026/backup-demo/Publish/README.txt"
yt-video-backup '2026/backup-demo'
```

With the one-script install, replace the last line with
`~/.scripts/yt-video-backup '2026/backup-demo'`. Wait for **Up to date**, then
find `Editing/2026/backup-demo/Publish/README.txt` on Drive's website. The
command refuses another run with the same name because the backup exists.
Keep the dummy folders until you have inspected them; remove only those
exact `backup-demo` folders when you are ready.

For a temporary script check with **no Drive copy**, run
`bash tests/test_yt_video_backup.sh` from this repo. It creates and removes
its own fixture.

## Back up a real video

1. Put the Final Cut library, source media, and export in one project folder,
   such as `~/Movies/Final Cut Projects/YouTube/2026/2026-11-03-my-video/`.
2. Close Final Cut Pro, Motion, Logic Pro, and Compressor so files stay still.
3. Run the command, replacing the example with your real folder name:

   ```bash
   yt-video-backup '2026/2026-11-03-my-video'
   ```

An absolute source path also works if it points inside the same
`YouTube/<year>/<project>/` layout.

## Check the result

| Check | What it proves |
|---|---|
| `Local copy verified` | The mounted Drive copy matched the local project at copy time. |
| Drive says **Up to date** | The desktop app reports that syncing finished. |
| Library and export visible on Drive's website | The expected files are visible remotely. |

Do all three before removing local originals. A folder name alone does not
prove that its media uploaded. The command's success message is a **local
copy check**, not a remote backup receipt.

## How it works

```text
Project on Mac → temporary folder in mounted Drive → compare files
              → final folder name → Drive sync → you check Drive website
```

The script checks the source location and year, requires the private Drive
variable, checks editing apps, and refuses to overwrite an existing backup.
If copying or comparison fails, it leaves a `.incomplete-...` folder for
inspection. Its comparison uses `rsync` in **dry-run mode**; it never uses
`rsync --delete` to remove files from Drive.

## Common problems

| Message or symptom | Next step |
|---|---|
| `Set MEDIA_BACKUP_DRIVE in ~/.secrets` | Add the example export line to your private file and open a new terminal. |
| `Google Drive YouTube folder is unavailable` | Check sign-in, the mounted account, and the `My Drive/.../YouTube` folder. |
| `Project folder not found` | Check the year and exact name. Keep the argument quoted. |
| `Close Final Cut Pro...` | Quit the named app, then retry. |
| `Backup already exists` | Inspect the existing backup. The command will not replace it. |
| `Copy check failed` | Keep the source. Inspect the printed `.incomplete-...` folder; it is not a finished backup. |
| Drive is still syncing | Wait and keep the source until remote files are visible. |

## Run it with an AI agent

An agent with local command access can run this script. A Drive MCP connector
alone cannot copy a local Final Cut project. Give the agent the exact project
folder name and ask it to:

- [ ] Check the source exists and editing apps are closed.
- [ ] Run the command and report its exit status.
- [ ] Report local copy, Drive sync, and remote visibility separately.
- [ ] Leave the source and any existing backup alone.

For a non-interactive local agent shell, use this form. It loads the private
variable without printing the contents of `~/.secrets`:

```bash
zsh -c 'source "$HOME/.secrets"; "$HOME/.scripts/yt-video-backup" "$1"' _ '2026/2026-11-03-my-video'
```

The agent can check remote visibility through a connected Drive tool or the
Drive website. If it cannot see the remote files, it should report that
check as **unverified**, even if the local command succeeded.
