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
├── Brewfile                   # Homebrew packages and casks
├── sync.sh                    # System -> repo sync script
├── install.sh                 # Repo -> system install script
├── server.sh                  # Remote server bootstrap script
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
