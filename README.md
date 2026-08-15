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
```

It requires the exact `nathanialhenniges/dotfiles` origin, the `main` branch,
and a clean worktree. It fetches and fast-forwards only, never commits or
pushes. Ubuntu runs only `linux-desktop.sh`; macOS runs the explicit
apply-only list without Homebrew, packages, plugins, or Node setup. Existing
macOS files receive a one-time adjacent `.backup` that later runs preserve.

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
```

Sync captures per OS from the same mapping tables the installers apply from:
macOS writes `config/`, an Ubuntu desktop writes `profiles/linux-desktop/`.
Server and devbox configs are applied wholesale by `server-dev.sh` and are
never captured, so Linux requires `--profile` here too.

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
- `./update.sh` — Safely fast-forward and reapply desktop dotfiles on macOS or
  Ubuntu. Requires the trusted origin, `main`, and a clean worktree; supports
  `--dry-run` and never commits or pushes. Linux requires
  `--profile linux-desktop` so a server or devbox cannot be given the
  desktop profile by accident.
- `./sync.sh` — Pull the managed dotfiles for the current OS into the repo,
  rewrite absolute home paths to `$HOME`, skip `.gitconfig` and `.npmrc`, and
  merge the Brewfile without ever dropping an entry. Linux requires
  `--profile linux-desktop`.
- `./install.sh` — Install Homebrew (macOS) or apt essentials
  (Linux), Oh My Zsh + plugins, copy dotfiles, and set up
  Node.js via fnm.
- `./server.sh` — Bootstrap a remote Linux server with zsh,
  Oh My Zsh, and minimal server configs from `config/server/`.
- `./server-dev.sh` — Bootstrap a remote Linux **dev** server:
  everything `server.sh` does, plus fnm + Node, Docker, and dev
  CLIs (gh, direnv, bun, go, build-essential, jq, eza, btop),
  plus a MacBook-parity set (ncdu, gnupg, ffmpeg, rclone, yt-dlp,
  fastfetch, awscli, terraform, act) installed best-effort.
- `lib/bootstrap.sh` — Shared helper functions sourced by
  `server.sh` and `server-dev.sh` (base packages, Oh My Zsh,
  plugins, Oh My Posh, config copy, shell switch).
- `./mini.sh` — Minimal bootstrap: Homebrew plus a small package
  set (fnm, fzf, direnv, gh, Oh My Posh), Oh My Zsh + plugins,
  and dotfiles excluding the server/sharedhosting/ghostty configs.
- `./sharedhosting.sh` — Bootstrap a shared hosting environment
  (no root required, bash-based) with configs from `config/sharedhosting/`.

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
│   │   └── codex/
│   │       └── config.toml    # Linux-safe Codex config
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
├── mini.sh                    # Minimal bootstrap (fnm, fzf, direnv, gh)
├── server.sh                  # Remote server bootstrap script
├── server-dev.sh              # Remote Linux dev-server bootstrap
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
Homebrew, no Node.js. Safe to re-run to pull updated configs.

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

Optional flags:

```bash
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
`--pnpm` installs pnpm (both run after Node is set up, so npm is
available). Flags combine, e.g. `--agent-setup --chrome`.

Run `--help` (or `-h`) for the full flag list:

```bash
bash <(curl -fsSL .../server-dev.sh) --help
```

### Agent setup (`--agent-setup`)

Replicates the Claude Code + Codex setup on the box (implies
`--ai`). It:

- Installs the Claude Code + Codex CLIs (if not already).
- Writes a curated `~/.claude/settings.json` (model, permission
  allowlist, enabled plugins) — without the machine-specific
  hooks/statusline paths from the desktop config.
- Copies the skills pack into `~/.claude/skills/`.
- Adds the plugin marketplaces and installs the plugins
  (`claude plugin marketplace add` / `install`).
- Writes a Linux-safe `~/.codex/config.toml` (model + reasoning;
  drops the macOS-only MCP servers).
- Installs the **same plugins into Codex** — adds the same GitHub
  marketplaces and installs the plugin set via `codex plugin
  marketplace add` / `codex plugin add`.
- Pre-registers the Atlassian (Jira/Confluence) MCP for both
  Claude Code and Codex.

`--ai` (and therefore `--agent-setup`) also installs
`bubblewrap`, which Codex needs for its Linux sandbox.

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
