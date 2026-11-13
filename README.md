# dotfiles - Personal Development Environment

Configuration files and setup scripts for my development
environment. Everything is managed with simple copy scripts —
no symlinks, no stow, no risk of losing configs.

Your terminal is your workshop. Keep it sharp.

## Features

- **One-command setup** — Clone the repo and run `install.sh`
  to bootstrap a new machine with all dotfiles, packages,
  Oh My Zsh + plugins, and Node.js.
- **Simple sync** — Run `sync.sh` to capture your latest
  system dotfiles into the repo for version control.
- **Automatic backups** — Existing dotfiles are backed up
  before being overwritten during installation.
- **Brewfile** — Every Homebrew package, cask, Mac App Store
  app, and VS Code extension tracked in a single file.
- **Chrome Remote Desktop** — The Brewfile installs the host. After `brew bundle`, log out of macOS and back in, visit `https://remotedesktop.google.com/access`, enable remote access, name the Mac, set a strong PIN, and grant the requested Accessibility and Screen Recording permissions. Connect from Ubuntu through the same site and remember the PIN only on a trusted device.
- **Secrets management** — API keys and tokens stay in
  `~/.secrets`, which is never committed to git.

## Getting Started

> **Ubuntu Desktop:** do not run the general `install.sh`. Use the dedicated
> [`linux-setup`](https://github.com/nathanialhenniges/linux-setup) repository,
> which installs system packages first and then calls this repository's
> home-only `linux-desktop.sh`. Server and devbox setup remain separate.

1. Clone the repository:

```bash
git clone https://github.com/nathanialhenniges/dotfiles.git \
  ~/Developer/nathanialhenniges/dotfiles
```

2. Run the install script:

```bash
cd ~/Developer/nathanialhenniges/dotfiles
./install.sh
```

3. Restart your terminal to apply changes.

### OpenWrt travel router

Install Zsh, Oh My Posh, the MrDemonWolf server theme, and router aliases on an
OpenWrt router with root SSH access and `apk`. Ash remains the fallback if Zsh
is unavailable.

```bash
./travel-router.sh --dry-run
./travel-router.sh
```

Pass another SSH target when needed: `./travel-router.sh root@192.0.2.1`.

## Usage

Preview or apply only the Linux desktop home profile:

```bash
./linux-desktop.sh --dry-run
./linux-desktop.sh
```

This route uses no `sudo` or network calls. It backs up replaced files under
`${XDG_STATE_HOME:-$HOME/.local/state}/linux-setup/backups/`; that state path
must remain inside `HOME` and may not traverse symbolic links. It never copies
`.gitconfig`, agent, server, shared-hosting, Mac-only alias, or private
credential files.

The Linux Ghostty profile carries the portable parts of the Mac configuration,
uses the CaskaydiaCove Nerd Font installed by `linux-setup`, and launches
`/usr/bin/zsh` directly.
macOS-only titlebar, P3, blur, and Command-key options stay out of Ubuntu.

Update an already-configured Ubuntu desktop through its trusted setup checkout:

```bash
cd ~/linux-setup
git pull --ff-only
./setup.sh dotfiles
./setup.sh status
```

Rerunning `dotfiles` fast-forwards this repository's managed checkout and
reapplies only the allowlisted desktop profile. It does not invoke the general,
server, devbox, or agent installers.

For a direct checkout on either macOS or Ubuntu Desktop, use the guarded updater:

```bash
# macOS
./update.sh --dry-run
./update.sh

# Ubuntu Desktop — the profile must be named
./update.sh --profile linux-desktop --dry-run
./update.sh --profile linux-desktop

# Mac mini
./update.sh --profile mac-mini --dry-run
./update.sh --profile mac-mini
```

It requires the exact `nathanialhenniges/dotfiles` origin, the `main` branch,
and a clean worktree. It fetches and fast-forwards only, never commits or
pushes. Ubuntu runs only `linux-desktop.sh`; macOS runs the explicit
apply-only list, then upgrades claude-swap if already installed via pipx. It does
not rerun Homebrew, plugin, or Node setup. Existing
macOS files receive a one-time adjacent `.backup` that later runs preserve.

### claude-swap and CodexBar (standard macOS only)

[claude-swap](https://github.com/realiti4/claude-swap) requires Python 3.12+.
The Brewfile manages pipx and Python 3.13. Full `./install.sh` installs
claude-swap only when missing; reruns leave its version alone. For an existing
Mac, run these targeted commands from this checkout instead of rerunning the
full bootstrap:

```bash
brew install pipx python@3.13
# Only if not already installed via pipx:
pipx runpip claude-swap show claude-swap >/dev/null 2>&1 || \
  pipx install --python "$(brew --prefix python@3.13)/bin/python3.13" claude-swap
command -v pipx
command -v cswap
cswap --help
```

The managed Zsh files already add `~/.local/bin` once when it exists. Open a
new terminal after installation. `./update.sh` upgrades an existing pipx
installation with `pipx upgrade claude-swap`; `--dry-run` makes no changes.
You can also run that pipx command directly. Apply-only, Mac mini, Linux, and
server shell-only profiles do not install or upgrade this tool. Full dev-server
`--ai` / `--agent-setup` runs install it separately as described below.

Account setup is manual:

```bash
cswap add
cswap list
cswap --list --json
```

Leave credentials with claude-swap and macOS Keychain. Never copy credentials,
tokens, or account exports into this repository. Setup does not add or switch
accounts, enable automatic switching, log out, or modify Claude Code sessions.

In CodexBar, open **Preferences → Providers → Claude**, enable **Read accounts
from claude-swap**, and set the executable path to the exact output of
`command -v cswap` on that Mac. Refresh CodexBar and verify account monitoring;
CodexBar uses `cswap --list --json` for account information.

### Claude multiple accounts on a Linux dev server

Full `server-dev.sh --ai` or `--agent-setup` installs the same
[claude-swap](https://github.com/realiti4/claude-swap) tool through pipx and
adds `~/.local/bin` to the server shell PATH. Existing installs are retained;
upgrade explicitly with `pipx upgrade claude-swap`. The package-free
`--agent-setup-only` retry does not install the switcher.

Sign into and save each subscription account on the server, one at a time:

```bash
claude auth login
cswap add --alias personal
claude auth login
cswap add --alias work
cswap list
```

Choose the corresponding account in your laptop browser for each login.
Do not log out between accounts: upstream warns that logout can revoke the
saved refresh token. Never copy Mac credentials or account exports to the repo.
Setup installs the tool only; it does not register accounts or enable rotation.

```bash
cswap run personal --no-share-history
cswap run work --no-share-history
# Or change the shared default login used by plain claude:
cswap switch work
```

`run ... --no-share-history` launches that account in this terminal with its
own chat history. `switch` changes the shared default login; it does not
separate existing transcripts. Quit/relaunch Claude to make the selected
account unambiguous. These are convenience boundaries within one Linux user,
not separate OS security boundaries. Anthropic also documents native
[separate configuration directories](https://code.claude.com/docs/en/authentication#log-in-with-multiple-accounts)
for independent logins, settings, and history without a switcher.


For a completed YouTube edit, close Final Cut Pro, then run:

```bash
yt-video-backup '2026/2026-11-03-my-video'
```

The command copies the whole project to `My Drive/MultiMedia Projects/Social Media/YouTube/Editing/2026/` and checks the local copy. It will not replace an existing backup. See [the setup and agent guide](docs/yt-video-backup.md) and its [private-variable example](examples/yt-video-backup.env.example) before first use. Wait for Google Drive to show **Up to date**, then verify the folder and media are visible on Drive before removing original footage. This script is tracked at `config/.scripts/yt-video-backup` and installed at `~/.scripts/yt-video-backup`.

**Linux requires `--profile`.** A server or devbox provisioned by
`server-dev.sh` runs the `config/server` profile, and a bare run would assume
desktop and overwrite its shell config with the wrong file. Do not pass
`--profile linux-desktop` on a server or devbox.

Sync your current system dotfiles into the repo:

```bash
# macOS
./sync.sh

# Ubuntu Desktop
./sync.sh --profile linux-desktop

# Mac mini: capture only its dedicated shell profile
./sync.sh --profile mac-mini
```

Sync captures only the selected profile's managed files. The standard Mac
profile writes `config/`, an Ubuntu desktop writes `profiles/linux-desktop/`,
and the Mac mini writes only `profiles/mac-mini/.zshrc`. Server and devbox
configs are applied by `server-dev.sh` and are never captured.

The full Mac and Linux desktop syncs also merge portable agent skills. The
Mac mini profile skips those trees and the Brewfile, keeping its sync limited to
the shell config.

The MrDemonWolf YouTube Producer skill is backed up in
`config/agent/codex/skills/youtube-producer/`, including its approved artwork.
After changing the canonical source in the private `cli-ai-conversations` repo,
bump `**Skill version:**` in its `SKILL.md`, copy it into this folder and
`~/.codex/skills/youtube-producer/`, rebuild its
standalone and ChatGPT Web ZIPs, then run:

```bash
python3 scripts/check-youtube-producer-sync.py
```

The check compares local files and the version printed by the skill. It cannot
verify the installed ChatGPT Web skill; check that separately in ChatGPT Web.

Absolute home paths are rewritten to `$HOME` on capture, so a file recorded on
the Mac still works on the Ubuntu boxes. For public-repo safety, the sync
intentionally skips `.gitconfig` and `.npmrc`. Review and update those files
manually so machine IDs or registry tokens cannot be copied by accident.

Review the changes, then commit and push:

```bash
git diff
git add .
git commit -m "Update dotfiles"
git push
```

Install dotfiles onto a new machine:

```bash
./install.sh
```

Add a new dotfile by adding a `repo_path:home_path` line to
`macos_mappings` or `linux_mappings` in `lib/bootstrap.sh`, and the
matching entry to the apply table in `install.sh` or
`linux-desktop.sh`. `tests/test_sync_mappings.sh` fails if the two
drift apart. Then run `./sync.sh` to pull the file in.

### Manual macOS installs

**Optional, restricted access:** the eight personal Monokai Orca themes live in the private [nathanialhenniges/orca-monokai-pro](https://github.com/nathanialhenniges/orca-monokai-pro) repo. Access to these public dotfiles does not grant access to the themes. If your GitHub account has permission, run `gh auth login`, then `./install.sh --orca-themes-only`. The installer checks repository access before cloning or updating and stops with instructions if the check fails. Everyone else can skip this optional step; normal dotfiles setup does not use it. See [Orca theme setup](docs/orca-themes.md).

Apps with no Homebrew cask or Mac App Store listing. Download each one and
move the app to `/Applications` after `brew bundle` finishes.

| App | Download | Notes |
| --- | --- | --- |
| Open Screenshot Generator | [GitHub releases](https://github.com/dotnetdreamer/open-screenshot-generator/releases/latest) | App Store screenshot generator. Universal DMG. |
| veadotube mini | [itch.io](https://olmewe.itch.io/veadotube-mini) | PNGtuber avatar. Pick the Silicon build, not "macOS Intel". |
| Webcam Motion Capture | [webcammotioncapture.info](https://webcammotioncapture.info/) | Apple silicon zip. Includes Webcam Motion Receiver. |
| withoutBG | [withoutbg.com/mac](https://withoutbg.com/mac) ([releases](https://github.com/withoutbg/withoutbg-mac/releases/latest)) | Offline background removal. Apple Silicon, macOS 14+. |

### Codex → Claude Code sync (acs)

[acs](https://github.com/B0llerwagen/agent-config-sync) copies Codex skills
and MCP servers into Claude Code. It is not on npm (npm's `acs` is an
unrelated package), so it is not in the Brewfile. Build and link it from source:

```bash
git clone https://github.com/B0llerwagen/agent-config-sync ~/Developer/other/agent-config-sync
cd ~/Developer/other/agent-config-sync
npx -y pnpm install && npx -y pnpm build:cli
cd cli && npm link
```

Then, from `~`, set Codex as the source and sync:

```bash
acs init --user           # source: codex, target: claude-code
acs plan --user           # preview
acs sync --user           # apply
```

Set `"use_symlinks_for_skills": false` in `~/.acs.json`, or `acs sync` stops
to ask about symlinks even with `-y`. After a sync, run `./sync.sh` to back
the new skills up here.

## Tech Stack

| Layer           | Technology                              |
|-----------------|-----------------------------------------|
| Shell           | zsh + Oh My Zsh                         |
| Prompt          | Oh My Posh (custom theme)               |
| Plugins         | fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting |
| Node Manager    | fnm                                     |
| Package Manager | Homebrew                                |
| Terminal        | Ghostty (Liquid Glass theme)            |
| Editor          | Visual Studio Code                      |
| Git             | GPG commit signing via GnuPG            |
| Env Management  | direnv                                  |
| Languages       | Node.js, Go, PHP, Terraform            |
| Cloud           | AWS CLI, Google Cloud SDK               |
| Mobile          | Android Studio, Xcode, React Native     |

## Development

### Prerequisites

- macOS (Apple Silicon or Intel) or Linux (Debian/Ubuntu)
- Git
- Homebrew (installed automatically by `install.sh` on macOS)

### Setup

1. Clone the repo:

```bash
git clone https://github.com/nathanialhenniges/dotfiles.git \
  ~/Developer/nathanialhenniges/dotfiles
```

2. Run the installer:

```bash
cd ~/Developer/nathanialhenniges/dotfiles
./install.sh
```

### Development Scripts

- `./linux-desktop.sh` — Apply the explicit, home-only Ubuntu desktop profile.
  It does not install packages, change the login shell, fetch Git updates, or
  touch server/devbox and agent setup.
- `./update.sh` — Safely fast-forward and reapply the standard macOS profile,
  Ubuntu desktop profile, or Mac mini profile. Requires the trusted origin,
  `main`, and a clean worktree; supports `--dry-run` and never commits or pushes.
  Linux requires `--profile linux-desktop`; the mini uses `--profile mac-mini`.
- `./sync.sh` — Pull the managed dotfiles for the selected profile into the repo,
  rewrite absolute home paths to `$HOME`, skip `.gitconfig` and `.npmrc`, and
  merge the Brewfile on the full macOS profile. Use `--profile linux-desktop`
  or `--profile mac-mini` for those profiles.
- `./install.sh` — Install Homebrew (macOS) or apt essentials
  (Linux), Oh My Zsh + plugins, copy dotfiles, and set up
  Node.js via fnm.
- `./server.sh` — Bootstrap a remote Linux server with zsh,
  Oh My Zsh, and minimal server configs from `config/server/`.
- `./server-dev.sh` — Bootstrap a remote Linux **dev** server:
  everything `server.sh` does, plus fnm + Node, Docker, and dev
  CLIs (gh, direnv, bun, build-essential, jq, eza, btop),
  plus a MacBook-parity set (ncdu, gnupg, ffmpeg, rclone, yt-dlp,
  fastfetch, awscli, terraform, act) installed best-effort.
- `lib/bootstrap.sh` — Shared helper functions sourced by
  `server.sh` and `server-dev.sh` (base packages, Oh My Zsh,
  plugins, Oh My Posh, config copy, shell switch).
- `./mini.sh [--dry-run]` — Applies only `profiles/mac-mini/.zshrc`.
  It installs no packages or developer tools and preserves the first
  `~/.zshrc.backup`.
- `./sharedhosting.sh` — Bootstrap a shared hosting environment
  (no root required, bash-based) with configs from `config/sharedhosting/`.

### Failure modes this repo has already hit

Every one of these exited 0 while doing nothing, or did the wrong thing
without saying so. That is the pattern to design against here: **prefer a
loud refusal to a quiet no-op.** All are fixed and covered by `tests/`.

| What broke | Why it stayed hidden |
| --- | --- |
| `sync.sh` never ran on macOS | `declare -A` is a bash 4 feature and macOS ships 3.2. The loop aborted on a syntax error and the script still exited 0. |
| `brew bundle dump --force` deleted Brewfile entries | The dump only knows the machine running it, so another Mac's apps vanished with nothing in the diff to explain why. |
| Captures wrote `/Users/...` absolute paths | Valid on the Mac, dead weight on Ubuntu, and the file looked fine either way. |
| `update.sh` would apply the desktop profile to a devbox | Linux is not one thing. `mrdemonwolf-dev` and `kommit-dev` run the server profile. |
| Brewfile reordered on every sync | `sort` collation is locale-dependent: `en_US.UTF-8` puts `docker-compose` before `docker`, `C` reverses it. |
| `--prune` did nothing on Linux | The Brewfile section is macOS-only and the flag was silently ignored, which reads as "nothing to prune". |

Two rules fall out of that list, and both are enforced in code:

- **Never guess between profiles.** `--profile` is required on Linux for both
  `sync.sh` and `update.sh`. Auto-detection would be right until it was not,
  and the two scripts disagreeing would be worse than either answer.
- **Never report absence you cannot verify.** A category whose query tool is
  missing is skipped, not reported. Otherwise a box without `code` on `PATH`
  calls every VS Code extension dead and offers to delete them.

## Project Structure

```
dotfiles/
├── config/                    # Dotfiles mirroring ~/
│   ├── .zshrc                 # Zsh configuration
│   ├── .zprofile              # Zsh profile (Homebrew init)
│   ├── .p10k.zsh              # Powerlevel10k prompt config
│   ├── .profile               # Shell profile
│   ├── .aliases               # Custom shell aliases
│   ├── .gitconfig             # Git user and signing config
│   ├── .npmrc                 # npm registry config
│   ├── .nuxtrc                # Nuxt telemetry settings
│   ├── server/                # Server-only configs
│   │   ├── .zshrc             # Minimal server zsh config
│   │   └── .aliases           # Server-specific aliases
│   ├── sharedhosting/         # Shared hosting configs (no root)
│   │   ├── .bashrc            # Bash config for shared hosts
│   │   └── .aliases           # Shared hosting aliases
│   ├── agent/                 # AI agent config installed by --agent-setup
│   │   ├── claude/
│   │   │   ├── settings.json  # Curated Claude Code settings
│   │   │   └── skills/        # Skills pack copied to ~/.claude/skills/
│   │   ├── codex/
│   │   │   ├── config.toml    # Linux-safe Codex config
│   │   │   └── skills/        # Custom skills copied to ~/.codex/skills/
│   │   └── shared-skills.tsv  # Portable ~/.agents/skills discovery index
│   ├── .scripts/              # Custom scripts copied to ~/.scripts/
│   └── .config/
│       ├── ghostty/
│       │   └── config                # Ghostty terminal config (Liquid Glass)
│       └── ohmyposh/
│           └── mrdemonwolf.omp.json  # Oh My Posh theme
├── profiles/
│   └── linux-desktop/          # Isolated Ubuntu Desktop home profile
│       ├── .zshrc
│       ├── .aliases
│       └── .config/ghostty/config
├── lib/
│   └── bootstrap.sh           # Shared server bootstrap helpers
├── docs/
│   └── jira-mcp-setup.md      # Atlassian/Jira MCP OAuth setup guide
├── Brewfile                   # Homebrew packages and casks
├── sync.sh                    # System -> repo sync script
├── install.sh                 # Repo -> system install script
├── linux-desktop.sh           # Ubuntu Desktop home-only profile installer
├── update.sh                  # Guarded macOS/Ubuntu updater
├── mini.sh                    # Mac mini shell profile installer
├── server.sh                  # Remote server bootstrap script
├── server-dev.sh              # Remote Linux dev-server bootstrap
├── travel-router.sh           # OpenWrt Zsh and Oh My Posh bootstrap
├── sharedhosting.sh           # Shared hosting bootstrap (no root)
├── .gitignore
└── README.md
```

## Server Setup

Bootstrap a remote Linux server with a clean zsh environment
using a single command over SSH:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/server.sh)
```

This installs zsh, Oh My Zsh + plugins, and copies a minimal
shell config from `config/server/` — no macOS tooling, no
Homebrew, no Node.js.

For existing servers, update only the shell files:

```bash
bash ~/dotfiles/update.sh --profile server --dry-run
bash ~/dotfiles/update.sh --profile server
```

After the first update, reconnect and use `dotfiles-update` (or
`dotfiles-update --dry-run`). The updater requires a clean checkout on `main`
with the expected GitHub origin and fast-forwards it before applying the
server profile. No packages, services, firewall rules, or login shells change.
The dry run checks the current checkout without fetching newer files.

Edit shared settings in `config/server/`, review and publish them to GitHub,
then run the update command on each server account. Keep host-only additions
in `~/.zshrc.local` and `~/.aliases.local`; these are never copied or uploaded.
Updates refuse to overwrite locally edited managed files. Review those edits
and move host-only additions into the local files before trying again.
Changed files are backed up under `~/.server-dotfiles-backup.XXXXXX/`.
To roll back, copy the needed files from that backup into the same paths under
`~`, then reconnect. Updates are manual; there is no unattended pull job.

## Clone development repositories

The dev-server bootstrap creates `~/Developer`, `~/Library`, and `~/Downloads`.
It keeps the existing `~/dotfiles` checkout; Snap manages its own `~/snap` folder.

Run the one-off clone script separately after GitHub authentication:

```bash
gh auth login --hostname github.com
bash ~/dotfiles/scripts/clone-dev-repos.sh --dry-run
bash ~/dotfiles/scripts/clone-dev-repos.sh
```

Repositories go into `~/Developer/mrdemonwolf/`,
`~/Developer/nathanialhenniges/`, and `~/Developer/kommitai/`. All API pages are
read, including archived repos and forks. Private repositories require access
for the authenticated account and any required org SSO/token authorization.
Existing files, directories, and symlinks at repo destinations are skipped;
existing checkouts are never pulled or modified. Symlinked Developer/owner
folders are refused. Listing or clone failures produce a nonzero exit while
other owners/repos continue. Re-running retries missing repos. A failed clone
may leave a directory that needs inspection before retrying.

For an external drive, set `DEV_REPOS_ROOT` to its real, existing Developer
directory (not a symlink). A missing configured directory stops the script
before any GitHub calls or writes, so an unmounted drive cannot silently fall
back to the internal home folder.

To persist the choice for noninteractive Orca commands too, save the absolute
path as one line in `~/.config/dotfiles/dev-repos-root`. Keep this machine-local
file out of Git. An explicit `DEV_REPOS_ROOT` overrides the saved path.

```bash
DEV_REPOS_ROOT="/Volumes/Development/Developer" bash ~/dotfiles/scripts/clone-dev-repos.sh --dry-run
```

The script does not clone automatically during setup, install project
dependencies or initialize submodules. Normal Git history and any configured
Git LFS smudge downloads can use substantial disk space.

## Dev Server Setup

Bootstrap a remote **Linux dev server** — everything `server.sh`
sets up, plus a full development toolchain:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/server-dev.sh)
```

> ### ⚠ This does not harden the machine
>
> `server-dev.sh` does **not** touch `sshd`, does **not** configure a
> firewall, and does **not** install fail2ban, sysctl hardening, or
> unattended security upgrades. On a bare internet-facing host it
> leaves password SSH enabled and every port open. It also installs
> Docker, whose published ports bypass a host firewall even where one
> exists.
>
> That is deliberate. This is a dotfiles repo — shell config, editor
> config, dev tooling. Deciding who can reach a server is server
> devops: it belongs with the infrastructure code that owns those
> machines, and not in a public repo. Hardening used to live here and
> was moved out.
>
> **Run this on a box that is already secured** — behind a VPN, a
> bastion, a cloud security group, or provisioned by something that
> hardened it first. For a machine reachable from the internet, harden
> it before you install anything, then let this handle the dev
> environment.
>
> `--hostname` and `--no-firewall` were removed along with the
> hardening. Passing either now exits with an error rather than being
> silently ignored — being quietly dropped is how you end up believing
> a box was hardened.

Default installs include Node LTS, Bun, Docker, GitHub CLI, build tools, Python
with venv, ripgrep, ShellCheck, zip, and shell utilities. Go is not installed. Media/infrastructure extras and the full
Ubuntu docs restore are opt-in here. The private devbox wrapper requests the
full docs restore. Existing packages are never removed by this script.

Optional flags:

```bash
# browser tests: Chromium + WebKit and their Linux libraries
bash <(curl -fsSL .../server-dev.sh) --playwright

# WordPress/PHP development (CLI only)
bash <(curl -fsSL .../server-dev.sh) --php

# optional extra CLI bundle or full docs restore (flags combine)
bash <(curl -fsSL .../server-dev.sh) --extras
bash <(curl -fsSL .../server-dev.sh) --docs

# also install the Claude Code + Codex CLIs (npm globals)
bash <(curl -fsSL .../server-dev.sh) --ai

# also install pnpm
bash <(curl -fsSL .../server-dev.sh) --pnpm

# full agent setup: CLIs + plugins + skills + settings + Jira MCP
bash <(curl -fsSL .../server-dev.sh) --agent-setup

# redo ONLY the agent step on a box that's already provisioned
bash <(curl -fsSL .../server-dev.sh) --agent-setup-only

# headless Chrome/Chromium for browser automation + screenshots
bash <(curl -fsSL .../server-dev.sh) --chrome
```

`--ai` installs `@anthropic-ai/claude-code` and `@openai/codex`
globally via npm, plus `bubblewrap` (Codex's Linux sandbox);
`--pnpm` installs pnpm under `~/.local/bin`, so it stays available across
fnm Node versions (both run after Node is set up, so npm is
available). Flags combine, e.g. `--agent-setup --chrome`.

`--playwright` seeds Chromium and WebKit with Playwright 1.64.1, including
Linux libraries, Xvfb, and xauth for headed tests. It installs no global Playwright package. After installing a
project's locked dependencies, run its own Playwright CLI to get matching
browser binaries, for example from a workspace with `@playwright/test`:

```bash
npx --no-install playwright install --with-deps chromium
# For projects using iPhone/Safari emulation:
npx --no-install playwright install --with-deps webkit
```

For headed tests on a server without a display:

```bash
xvfb-run -a npx --no-install playwright test --headed --workers=1
```

For Playwright's graphical UI, start this inside the project's Playwright
workspace on the server:

```bash
xvfb-run -a npx --no-install playwright test --ui --ui-host=127.0.0.1 --ui-port=9323 --workers=1
```

On the Mac, forward that port using the server's working SSH alias/address:

```bash
ssh -N -L 9323:127.0.0.1:9323 user@devbox
```

Open `http://127.0.0.1:9323` in the Mac browser. This shows Playwright's test UI
and trace snapshots; it is not a remote desktop or a streamed live browser.
The listener stays on loopback and needs no public firewall port. One worker
is the conservative starting point for a 2-core, 12 GB devbox. No desktop,
VNC service, or background Xvfb service is installed.

Only the selected browsers are installed; Firefox is not included by default.
System Chrome (`--chrome`) is separate and is only needed for tools configured
to use that system browser. Google Chrome is installed from Google's apt repo
on both amd64 and arm64; other architectures keep the Chromium fallback.
`--php` installs the distro PHP CLI (8.3 on Ubuntu
24.04), Composer, and curl/mbstring/XML/zip extensions. Apache, PHP-FPM, databases,
and global PHPUnit/PHPStan/PHPCS are not installed. Use `composer install` in
the project for its locked test tools. Python packages belong in project venvs.
Project manifests may pin different Bun/Node releases; use those versions for
reproducible builds. Cloudflare, Expo/EAS, linters, and other JS CLIs should use
the project's installed dependencies or its documented invocation.

Run `--help` (or `-h`) for the full flag list:

```bash
bash <(curl -fsSL .../server-dev.sh) --help
```

### Agent setup (`--agent-setup`)

Replicates the Claude Code + Codex setup on the box (implies
`--ai`). It:

- Installs the Claude Code + Codex CLIs (if not already).
- Writes curated `~/.claude/settings.json` (model, permission
  allowlist, enabled plugins, and the portable shared status line), while
  preserving any prior local status command.
- Copies the Claude and custom Codex skill packs into `~/.claude/skills/` and
  `~/.codex/skills/`, then recreates the shared `~/.agents/skills/` index.
- Adds the plugin marketplaces and installs the plugins
  (`claude plugin marketplace add` / `install`).
- Writes a Linux-safe `~/.codex/config.toml` (model + reasoning;
  drops the macOS-only MCP servers).
- Installs the **same plugins into Codex** — adds the same GitHub
  marketplaces and installs the plugin set via `codex plugin
  marketplace add` / `codex plugin add`.
- Registers Jira/Atlassian, OpenAI Developer Docs, Mobbin, and Dub Links for
  both clients. Claude definitions use user scope, so they apply to every
  project. Existing Codex MCP definitions and plugin registrations are preserved.
  Authentication remains a separate owner step; no Mac credentials are copied.

`--orca-server` also configures a private Orca runtime reached through SSH.
The targeted Mac equivalent is `bash install.sh --orca-server-only`.
On the Mac client, `bash install.sh --orca-tunnels-only` keeps the SSH forwards
running (`orca-tunnels status`).
See [Orca server setup](docs/orca-server.md) for pairing and client commands.

### Android development with a physical device on macOS

Run the targeted setup on an existing Mac with Homebrew:

```bash
cd ~/dotfiles
bash install.sh --android-tools-only --dry-run
bash install.sh --android-tools-only
```

On a new Mac, `bash install.sh --android-tools` includes this step in the full
bootstrap. The targeted command leaves the rest of the workstation setup alone.

This reuses Java 21 or installs Temurin 21, adds Android SDK command-line tools,
ADB, Android platforms 36/37.0 and build-tools 36/37, and accepts the required
SDK package licenses. Existing packages remain. It installs no Android Studio
IDE, emulator, system images, or NDK. The default SDK is `~/Library/Android/sdk`;
an existing `ANDROID_HOME` selects another SDK. Java 21 and SDK paths are saved
in a machine-local Zsh file, loaded by both login and interactive shells, with
each original startup file backed up once.
Repeat runs reuse the JDK and SDK packages already installed.

Open a new terminal, then connect the phone to that Mac with a data-capable
USB cable, enable USB debugging, and approve that Mac on the phone:

```bash
adb devices -l
adb install -r /path/to/app-debug.apk
```

For Android 11 or newer on the same trusted LAN, wireless debugging can replace
USB. Enable it on the phone, select pairing with a code, then run:

```bash
adb pair PHONE_IP:PAIRING_PORT
adb connect PHONE_IP:DEBUGGING_PORT
adb devices -l
```

Enter the temporary pairing code at ADB's prompt. Pairing and debugging ports
may differ. Each Mac needs its own phone authorization; do not copy ADB private
keys between Macs or publish ADB ports. APK installation and device tests happen
only after you connect and authorize the device.

For a paired phone that disconnects, `adb mdns services` lists its current
`_adb-tls-connect._tcp` address; use that debugging port with `adb connect`.
The pairing and debugging ports are different and can change. Unlock the phone
normally and keep its screen awake for UI tests. A black screenshot while the
display is asleep is not proof that capture is blocked.

Select the specific phone when sending input or capturing a screenshot:

```bash
device=PHONE_IP:DEBUGGING_PORT
adb -s "$device" shell input keyevent KEYCODE_WAKEUP
adb -s "$device" shell input keyevent KEYCODE_HOME
adb -s "$device" exec-out screencap -p > "$HOME/Downloads/android-screen.png"
```

The screenshot is saved on whichever Mac runs this command. Keep screenshots
private; do not commit phone images, pairing codes, or ADB keys. These commands
do not unlock the phone or prove that an application builds or runs correctly.

### Global agent instructions

Global communication preferences live in `config/agent/shared/communication.md`.
Run `python3 scripts/apply-agent-instructions.py` to apply them to Codex, Claude,
and the home-level `AGENTS.md` without replacing personal instructions. New chats
load the ADHD-friendly summary, table, checklist, and visual preferences.

`--ai` (and therefore `--agent-setup`) also installs
`bubblewrap`, which Codex needs for its Linux sandbox.

### Shared Claude + Codex status line

Apply the portable status line to the current device without running the full
bootstrap:

```bash
./scripts/apply-agent-statusline.py --dry-run
./scripts/apply-agent-statusline.py
```

Claude Code gets a two-row, Powerline-inspired status line with model/reasoning,
project and Git state, context use, available five-hour and seven-day rate
windows, and spend information when the provider exposes it. An existing custom
Claude status command is saved locally and its output is retained. Codex uses
its native colored footer for model, directory, branch, changes, context, and
five-hour/weekly usage; the native footer does not expose the same custom
layout or a credit-balance segment. Codex `/status` remains the place to check
the account credit balance. The apply script preserves existing settings and
keeps the first adjacent `.backup` files.

### Global agent instructions (`config/agent/rules/`)

Rules that every agent on every box should follow live in
`config/agent/rules/`. They are the canonical copy, kept under version
control so all three machines can be brought back into agreement.

They are **not** in the sync or apply mapping tables, and that is
deliberate. Both destinations already hold content nobody else owns:
`~/.claude/CLAUDE.md` on the Mac carries 200+ lines of project notes, and
`~/.codex/AGENTS.md` is hand-written per machine. An installer that copied
over either would delete work no backup would obviously explain. Paste a
rule in by hand when you add or change one.

Current rules:

- `remove-ai-marks.md` — always strip AI provenance marks (invisible
  Unicode, C2PA/EXIF/XMP) from docs, copy, and media before publishing.
  Never over source code.

Existing `settings.json` / `config.toml` are backed up to
`*.backup` first.

#### Re-running just this step (`--agent-setup-only`)

```bash
bash <(curl -fsSL .../server-dev.sh) --agent-setup-only
```

Runs `--agent-setup` and nothing else — no apt, no Docker, no
`chsh`, no dotfile copies. It still pulls the dotfiles repo first,
so it picks up any change to the plugin list.

Use it to retry installs that failed, or to pick up a plugin added
to the arrays since the box was built, without a full rebuild.

It refuses to run on a box that was never provisioned — with no
Node there is nothing to install the CLIs with, so it would copy
the settings and skills and then skip every plugin, leaving a box
that looks configured and isn't. Use `--agent-setup` there.

**None of it requires being logged in to Claude Code.** Marketplace
adds are `git clone` and installs are file copies — no call reaches
the Anthropic API, so plugins install fine on a box that has never
been signed in. Log in whenever you like; it's unrelated. It also
does not activate a shell for you, so it puts an already-installed
fnm/Node on `PATH` itself rather than reinstalling the CLIs it
can't see.

#### When a plugin doesn't install

Marketplace and plugin steps print `FAILED` plus the actual error,
and the end of `--agent-setup` lists everything that failed. A
plugin you already have is reported as `(already present)` and is
not a failure. Nothing about the plugin step is silent — an
earlier version swallowed all of it into one "already installed or
unavailable" line, and a provisioning run reported success while
installing nothing.

The marketplace list in `server-dev.sh` is written as
`owner/repo=alias`. The alias is **not** the repo name — it comes
from the `name` field in that repo's
`.claude-plugin/marketplace.json`, and `expo/skills` registers as
`expo-plugins`. `AGENT_PLUGINS` entries are checked against those
aliases before anything is installed.

#### The submodule fallback

`expo/skills` can't be added the normal way. It carries a git
submodule pointing at `expo/eval-experiments`, which is private
(added in expo/skills#105 for Expo's own eval CI — no use to anyone
installing the plugin). Claude Code clones marketplaces with
`--recurse-submodules`, so the clone aborts and nothing registers.
Codex doesn't recurse, which is why codex installs the same repo
without complaint. Tracked upstream in expo/skills#110.

When a marketplace add fails, the script retries once by cloning
the repo with `--no-recurse-submodules` into
`~/.local/share/claude-marketplaces/` and adding *that directory*.
Same alias, same plugins. You'll see:

```
    FAILED  claude marketplace expo/skills
            fatal: clone of '.../eval-experiments.git' into submodule path ... failed
    claude marketplace expo/skills (via submodule-free local clone)
    claude plugin expo@expo-plugins
```

The `FAILED` line stays — it's what actually happened — but the
step is dropped from the closing failure summary, because it was
repaired. Reporting a fixed step as failed is the same lie as
reporting a failed step as fine, just pointing the other way.

This only runs *after* the normal add has failed, so the day Expo
drops the submodule the ordinary path wins and the fallback goes
dormant on its own. Nothing to remember to undo.
`extraKnownMarketplaces` in `settings.json` still names the GitHub
source deliberately — that's the intent; the local clone is the
workaround, not the goal.

**Jira/Atlassian needs a one-time OAuth login** — it can't be
provisioned headlessly. See
[docs/jira-mcp-setup.md](docs/jira-mcp-setup.md).

**Prerequisite:** create the sudo account and add your SSH public
key to its `~/.ssh/authorized_keys` **first**, then run this as
that account. This script does not create the user, and it does
not secure the machine — see the warning above.

On top of the base zsh environment, this installs:

- **fnm + latest LTS Node.js** — with `--use-on-cd` auto-switching
- **Docker** — via the official `get.docker.com` script; your
  user is added to the `docker` group (log out/in to apply)
- **Dev CLIs** — `gh`, `direnv`, `bun`, `go`, `build-essential`,
  `jq`, `eza`, `btop`

It also creates a basic home layout (`~/Developer`,
`~/Downloads`; skipped if they exist).

### What it deliberately does not do

No `sshd` changes. No firewall. No fail2ban. No sysctl. No
unattended upgrades. No hostname changes.

All of that used to live here and now lives with the
infrastructure code that provisions these machines. Two reasons:

- **A dotfiles repo is the wrong home for a security posture.**
  Shell config and firewall rules have different blast radii and
  different review needs. Mixing them meant a change to either
  looked like a change to "dotfiles".
- **This repo is public.** How our servers decide who gets in is
  not something to publish, and the details that make hardening
  correct for *our* boxes are exactly the details that make it
  wrong for someone else's.

**Docker is the sharp edge.** This script installs it, and Docker
publishes container ports straight into netfilter's `nat` table,
below a host firewall's INPUT rules. A container started with
`-p 3000:3000` is reachable from anywhere that can route to the
host, no matter what `ufw status` says — and `ufw status` will
not mention it. Bind app ports to `127.0.0.1` and reach them with
`ssh -L` (below), or make sure whatever provisioned the box
installed a `DOCKER-USER` default-deny.

Whatever hardens the box should run **before** this script, not
after. Any of the ~15 network-dependent installs here can fail on
a flaky mirror, and under `set -e` that aborts the run — leaving
a box with Docker installed and nothing else done. Harden first
and a failed toolchain install costs you tooling, not exposure.

`nmap` from off-box is the only honest check that a host is
closed; `ufw status` is not evidence.

Linux only (exits early on macOS — use `install.sh` there).
Safe to re-run.

### Headless browser (`--chrome`)

Installs a headless-capable browser so automation tools can drive
it and take screenshots — Google Chrome on `amd64`, Chromium on
other arches, plus rendering fonts.

Quick smoke test:

```bash
google-chrome-stable --headless=new --screenshot=/tmp/shot.png \
  --window-size=1280,800 https://example.com && ls -la /tmp/shot.png
```

**`--chrome` installs the browser only.** Unlike the Atlassian
MCP, a browser MCP is **not** registered for you — without one,
Claude Code and Codex cannot drive Chrome. Add it per client:

```bash
# Claude Code
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

```toml
# Codex — add to ~/.codex/config.toml
[mcp_servers.chrome-devtools]
command = "npx"
args = ["-y", "chrome-devtools-mcp@latest"]
```

Puppeteer/Playwright scripts can point at the installed binary
(`google-chrome-stable`) instead of downloading their own.

### After it runs

The script prints these next steps when it finishes:

1. **Reconnect** (or run `zsh`) to start using zsh + fnm.
2. **Log out and back in** for Docker group membership to apply
   (then `docker run hello-world` should work without `sudo`).
3. **`gh auth login`** to authenticate the GitHub CLI (see the
   single-org scoping note below).
4. **Forward dev ports** from your laptop with `ssh -L` (see
   below).

`sshd` is not restarted by this script, so there is no
verify-before-you-disconnect step — but if something else
hardened the box, that step belongs to *that* tool and you should
still do it.

### Reaching dev ports over SSH

Reach a dev server's app ports (Vite, Node, etc.) by tunnelling
them over your existing SSH connection rather than opening
inbound holes. Right approach regardless of what is filtering the
host — and the only one that also covers Docker-published ports,
which bypass a host firewall entirely.

Ad-hoc, per session:

```bash
ssh -L 3000:localhost:3000 -L 5173:localhost:5173 user@devbox
```

Now `http://localhost:3000` on your laptop hits the server's
port 3000.

Persistent — add this to `~/.ssh/config` **on your laptop** (not
the server) so a bare `ssh devbox` opens the forwards every time:

```
Host devbox
    HostName <server-ip>
    User <your-user>
    LocalForward 3000 localhost:3000
    LocalForward 5173 localhost:5173
```

Add one `LocalForward <local-port> localhost:<remote-port>` line
per port you use.

### Scoped GitHub CLI login (single org)

The script installs the GitHub CLI but does **not** log you in —
`gh auth login` is interactive and token-scoped, so it stays a
manual step.

A standard `gh auth login` authenticates your **account**, which
means gh can see every organization you belong to. Scope lives on
the **token**, not the org. To restrict gh to just one org:

1. Create a **fine-grained personal access token**: GitHub →
   **Settings → Developer settings → Fine-grained tokens**.
2. Set **Resource owner** to that org and select only its repos
   (plus whatever repository permissions you need).
3. Log in with the token instead of the browser flow:

```bash
gh auth login --with-token < token.txt
```

That token physically cannot touch any other org, so gh is
effectively locked to the one you scoped it to.

## Shared Hosting Setup

Bootstrap a shared hosting environment where you have no root
access — pure bash, no package installs:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/sharedhosting.sh)
```

This copies configs from `config/sharedhosting/` to set up a
comfortable shell environment on hosts like cPanel, Plesk, etc.

## GitHub Codespaces

This repo works automatically with
[GitHub Codespaces](https://github.com/features/codespaces).
When you create a Codespace, GitHub clones your `dotfiles` repo
and runs `install.sh`. The script detects Linux and installs
lightweight essentials (`zsh`, `git`, `curl`, `wget`, `fzf`)
via `apt` instead of Homebrew. macOS-specific shell config
(Homebrew paths, Android SDK, Oh My Posh, etc.) is skipped on
Linux so your shell loads cleanly.

To enable this, go to **Settings > Codespaces** on GitHub and
set your dotfiles repository to `nathanialhenniges/dotfiles`.

## License

![GitHub license](https://img.shields.io/github/license/nathanialhenniges/dotfiles.svg?style=for-the-badge&logo=github)

## Contact

- Discord: [Join my server](https://mrdwolf.net/discord)

Made with love by [MrDemonWolf, Inc.](https://www.mrdemonwolf.com)
