# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles repo for macOS (Apple Silicon + Intel) and Linux (GitHub Codespaces). Uses plain copy scripts — no symlinks, no stow. Dotfiles live in `config/` mirroring `~/` structure.

## Key Scripts

- `./install.sh` — Full bootstrap for a new machine: installs Homebrew + Brewfile (macOS) or apt essentials (Linux), Oh My Zsh + plugins (fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting), copies dotfiles from `config/` to `~` (skips `config/server/`), and installs the latest Node.js via fnm.
- `./sync.sh` — Copies dotfiles from `~` back into `config/` and regenerates the Brewfile. **macOS only** (uses `brew bundle dump`).
- `./server.sh` — Standalone bootstrap for remote Linux servers. Clones the repo, installs zsh + essentials via apt, Oh My Zsh + plugins, copies configs from `config/server/` to `~`, and switches default shell to zsh. Designed to run as a one-liner: `bash <(curl -fsSL ...)`. Sources shared helpers from `lib/bootstrap.sh`.
- `./server-dev.sh` — Linux-only dev-server bootstrap. Does everything `server.sh` does (via the same `lib/bootstrap.sh` helpers), then installs dev tooling: fnm + latest LTS Node, Docker (official `get.docker.com` script, adds user to the docker group), and dev CLIs (gh, direnv, bun, go, build-essential, jq, eza, btop). Then applies **always-on base hardening** ported from the `mrdemonwolf/server-setup` Ansible roles: key-only sshd drop-in (`/etc/ssh/sshd_config.d/99-hardening.conf`, `PermitRootLogin prohibit-password`, `PasswordAuthentication no` — **guarded**: only disabled when the running user has `~/.ssh/authorized_keys`, else left on with a warning), UFW default-deny with SSH-only (skippable — see `--no-firewall`), sysctl (`/etc/sysctl.d/99-hardening.conf`), fail2ban (default sshd jail), and unattended security upgrades. Creates a basic home layout (`~/Developer`, `~/Downloads`; idempotent). Does NOT create the user (create the sudo account + add your key first). Dev app ports are reached via `ssh -L` forwarding, not opened in UFW. Optional flags: `--hostname <name|random>` sets the hostname (`hostnamectl` + `/etc/hosts` `127.0.1.1` line; `random` picks from a wolf-themed list `$WOLF_HOSTNAMES`); `--ai` also installs the Claude Code (`@anthropic-ai/claude-code`) + Codex (`@openai/codex`) CLIs as npm globals; `--pnpm` installs pnpm (both opt-in, run after fnm/Node via the shared `npm_global_cmd` helper). `--agent-setup` (implies `--ai`) replicates the agent config from `config/agent/`: curated `~/.claude/settings.json` (no machine-specific hooks/statusline), copies the skills pack to `~/.claude/skills/`, adds the shared GitHub plugin marketplaces + installs the plugin set into BOTH Claude Code (`claude plugin ...`) and Codex (`codex plugin ...`) from the same `AGENT_MARKETPLACES`/`AGENT_PLUGINS` arrays, writes a Linux-safe `~/.codex/config.toml`, and pre-registers the Atlassian (Jira) MCP for both (OAuth login is manual — see `docs/jira-mcp-setup.md`). `--ai` also installs `bubblewrap` (Codex Linux sandbox). Vendored agent assets live in `config/agent/{claude,codex}/`. `--chrome` installs a headless-capable browser for automation/screenshots (Google Chrome on amd64, Chromium on other arches, + fonts-liberation) — it installs the browser ONLY; a browser MCP (`chrome-devtools-mcp`) is NOT auto-registered and must be added manually to Claude Code and Codex before either can drive it. `--no-firewall` skips `harden_firewall` entirely (guard lives in `harden_server`, not in the function) — opt-in, for hosts already behind a provider firewall (cloud security groups / VPC rules) that is editable without host access and that Docker cannot publish past; default stays UFW-on because a host with nothing in front of it would otherwise get no filtering at all. `-h/--help` prints an embedded usage block (must NOT be self-grepped from `$0` — under `bash <(curl ...)` that pipe is already consumed and prints nothing). One-liner: `bash <(curl -fsSL ...server-dev.sh) [--hostname random] [--ai] [--pnpm] [--agent-setup] [--chrome] [--no-firewall]`. Exits early on macOS. gh login stays manual (interactive + token-scoped).
- `lib/bootstrap.sh` — Shared bootstrap helper functions (`log`, `substep`, `detect_os`, `install_base_packages`, `install_oh_my_zsh`, `install_zsh_plugins`, `install_oh_my_posh`, `copy_configs`, `set_default_shell`) sourced by `server.sh` and `server-dev.sh`. Add new shared setup steps here rather than duplicating across scripts. **Not** copied to `~` (lives outside `config/`).
- `./sharedhosting.sh` — Bootstrap for shared hosting (no root). Copies configs from `config/sharedhosting/` (`.bashrc`, `.aliases`). Pure bash, no package installs.

## Architecture

- `config/` — All dotfiles, mirroring home directory structure. `config/.zshrc` becomes `~/.zshrc`, `config/.config/ohmyposh/` becomes `~/.config/ohmyposh/`, etc. `config/server/` holds server-only configs (minimal `.zshrc`, `.aliases`) and is excluded from `install.sh`. `config/sharedhosting/` holds shared hosting configs (`.bashrc`, `.aliases`) used by `sharedhosting.sh`.
- **Exception:** Ghostty config lives in `config/.config/ghostty/` in the repo but `install.sh` maps it to `~/Library/Application Support/com.mitchellh.ghostty/` on macOS (where Ghostty actually reads it). `sync.sh` pulls from that Application Support path.
- `Brewfile` — Homebrew packages, casks, Mac App Store apps, and VS Code extensions. Auto-generated by `sync.sh`.
- `.zprofile` detects Apple Silicon (`/opt/homebrew`) vs Intel (`/usr/local`) Homebrew paths.
- `.zshrc` and `.zprofile` use `uname` checks (`Darwin` vs Linux) to conditionally run macOS-specific blocks (Homebrew paths, Android SDK, Oh My Posh, fnm, etc.).

## Conventions

- When adding a new dotfile: add it to the `files` array in `sync.sh`, then run `./sync.sh`. For nested paths under `~/.config/`, add an explicit `cp` command in the nested config section of `sync.sh`.
- Custom scripts live in `~/.scripts/` (hidden folder) and are tracked in `config/.scripts/`. `install.sh` copies them to `~/.scripts/` and makes them executable. `sync.sh` pulls them back.
- `~/.secrets` holds API keys/tokens and is gitignored — never commit secrets. Secrets are sourced at the end of `.zshrc`.
- `*.backup` files are gitignored (created by `install.sh` when overwriting existing dotfiles).
- Shell config assumes zsh with Oh My Zsh. Plugins: git, fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting.
- `.zshrc` uses direnv for per-directory environment variables (`eval "$(direnv hook zsh)"`).
- Ghostty config uses a Liquid Glass theme with transparency and blur (`background-opacity: 0.90`, `background-blur-radius: 90`).
