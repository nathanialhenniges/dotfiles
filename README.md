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
- **Secrets management** — API keys and tokens stay in
  `~/.secrets`, which is never committed to git.

## Getting Started

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

Sync your current system dotfiles into the repo:

```bash
./sync.sh
```

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

Add a new dotfile by editing the `files` array in `sync.sh`,
then running `./sync.sh` to pull it in. For nested paths under
`~/.config/`, add a `cp` command in the nested config section
of the script.

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

- `./sync.sh` — Pull dotfiles from your system into the repo
  and regenerate the Brewfile.
- `./install.sh` — Install Homebrew (macOS) or apt essentials
  (Linux), Oh My Zsh + plugins, copy dotfiles, and set up
  Node.js via fnm.
- `./server.sh` — Bootstrap a remote Linux server with zsh,
  Oh My Zsh, and minimal server configs from `config/server/`.
- `./server-dev.sh` — Bootstrap a remote Linux **dev** server:
  everything `server.sh` does, plus fnm + Node, Docker, and dev
  CLIs (gh, direnv, bun, go, build-essential, jq, eza, btop).
- `lib/bootstrap.sh` — Shared helper functions sourced by
  `server.sh` and `server-dev.sh` (base packages, Oh My Zsh,
  plugins, Oh My Posh, config copy, shell switch).
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
│   └── .config/
│       ├── ghostty/
│       │   └── config                # Ghostty terminal config (Liquid Glass)
│       └── ohmyposh/
│           └── mrdemonwolf.omp.json  # Oh My Posh theme
├── lib/
│   └── bootstrap.sh           # Shared server bootstrap helpers
├── Brewfile                   # Homebrew packages and casks
├── sync.sh                    # System -> repo sync script
├── install.sh                 # Repo -> system install script
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
sets up, plus a full development toolchain **and semi-lockdown
hardening** — with one command over SSH:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/server-dev.sh)
```

Optional flags:

```bash
# explicit hostname
bash <(curl -fsSL .../server-dev.sh) --hostname devbox

# random wolf-themed hostname (fenrir, luna, timber, sirius, …)
bash <(curl -fsSL .../server-dev.sh) --hostname random

# also install the Claude Code + Codex CLIs (npm globals)
bash <(curl -fsSL .../server-dev.sh) --ai

# also install pnpm
bash <(curl -fsSL .../server-dev.sh) --pnpm

# full agent setup: CLIs + plugins + skills + settings + Jira MCP
bash <(curl -fsSL .../server-dev.sh) --agent-setup

# headless Chrome/Chromium for browser automation + screenshots
bash <(curl -fsSL .../server-dev.sh) --chrome
```

`--hostname` (omit to leave it unchanged) updates both
`hostnamectl` and the `/etc/hosts` `127.0.1.1` line. `--ai`
installs `@anthropic-ai/claude-code` and `@openai/codex`
globally via npm; `--pnpm` installs pnpm (both run after Node is
set up, so npm is available). Flags combine, e.g.
`--hostname random --ai --pnpm`.

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
  drops the macOS-only MCP servers). Codex plugins are
  macOS-app-local — re-add them manually if wanted.
- Pre-registers the Atlassian (Jira/Confluence) MCP for both
  Claude Code and Codex.

Existing `settings.json` / `config.toml` are backed up to
`*.backup` first.

**Jira/Atlassian needs a one-time OAuth login** — it can't be
provisioned headlessly. See
[docs/jira-mcp-setup.md](docs/jira-mcp-setup.md).

### Headless browser (`--chrome`)

Installs a headless-capable browser so automation tools can drive
it and take screenshots — Google Chrome on `amd64`, Chromium on
other arches, plus rendering fonts.

Quick smoke test:

```bash
google-chrome-stable --headless=new --screenshot=/tmp/shot.png \
  --window-size=1280,800 https://example.com && ls -la /tmp/shot.png
```

To let Claude Code / Codex *drive* the browser (click, read,
screenshot), add a browser MCP that targets the system Chrome,
e.g.:

```bash
claude mcp add chrome-devtools -- npx chrome-devtools-mcp@latest
```

Puppeteer/Playwright scripts can point at the installed binary
(`google-chrome-stable`) instead of downloading their own.

**Prerequisite:** create the sudo account and add your SSH public
key to its `~/.ssh/authorized_keys` **first**, then run this as
that account. The script hardens the box — it does not create the
user.

On top of the base zsh environment, this installs:

- **fnm + latest Node.js** — with `--use-on-cd` auto-switching
- **Docker** — via the official `get.docker.com` script; your
  user is added to the `docker` group (log out/in to apply)
- **Dev CLIs** — `gh`, `direnv`, `bun`, `go`, `build-essential`,
  `jq`, `eza`, `btop`

It also creates a basic home layout (`~/Developer`,
`~/Downloads`; skipped if they exist).

And it applies **base hardening** (ported from the
[server-setup](https://github.com/MrDemonWolf/server-setup)
Ansible roles):

- **Key-only SSH** — hardened `sshd` drop-in: `PermitRootLogin
  prohibit-password`, `PasswordAuthentication no`, `MaxAuthTries
  3`, keep-alives. Validated with `sshd -t` before restart.
- **UFW firewall** — default-deny inbound, **SSH (22) only**
  open. Reach dev app ports via SSH forwarding (below).
- **sysctl** — anti-spoof, SYN-flood, and ICMP-redirect
  protections.
- **fail2ban** — bans SSH brute-force (default `sshd` jail).
- **Unattended security upgrades** — hands-free patching, no
  auto-reboot.

**Lockout guard:** `PasswordAuthentication no` is only applied
when the running user already has `~/.ssh/authorized_keys`. No
key → password auth is left on and you get a warning, so a
keyless box never becomes unreachable. After it runs, **open a
second SSH session to confirm key login works before you
disconnect the first one.**

Linux only (exits early on macOS — use `install.sh` there).
Safe to re-run; hardening is idempotent.

### After it runs

The script prints these next steps when it finishes:

1. **Open a second SSH session now** to confirm key login still
   works before you disconnect the first — `sshd` was just
   restarted.
2. **Reconnect** (or run `zsh`) to start using zsh + fnm.
3. **Log out and back in** for Docker group membership to apply
   (then `docker run hello-world` should work without `sudo`).
4. **`gh auth login`** to authenticate the GitHub CLI (see the
   single-org scoping note below).
5. **Forward dev ports** from your laptop with `ssh -L` (see
   below).

### Reaching dev ports over SSH

Because UFW opens **only** SSH, you reach a dev server's app
ports (Vite, Node, etc.) by tunnelling them over your existing
SSH connection — no inbound firewall holes needed.

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
