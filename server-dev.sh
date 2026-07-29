#!/bin/bash
# Bootstrap a remote Linux dev server: clean zsh env + dev tooling.
# Installs everything server.sh does, plus fnm/Node, Docker, and dev CLIs
# (gh, direnv, bun, go, build-essential, jq, eza, btop).
#
# ⚠️  THIS SCRIPT DOES NOT HARDEN THE MACHINE.
#
#     It does not touch sshd, does not configure a firewall, does not install
#     fail2ban, does not apply sysctl hardening, and does not enable unattended
#     security upgrades. Run on a bare internet-facing host it will leave
#     password SSH enabled and every port open. It installs Docker, whose
#     published ports bypass a host firewall even when one is present.
#
#     That is deliberate, not an oversight. This is a dotfiles repo: shell
#     config, editor config, dev tooling. Deciding who can reach a server is
#     server devops, it belongs with the infrastructure code that owns those
#     machines, and it does not belong in a public repo. Hardening used to live
#     here and was moved out.
#
#     Use this on a box that is ALREADY secured — behind a VPN, a bastion, a
#     cloud security group, or provisioned by something that hardened it first.
#     For a machine reachable from the internet, provision it with a tool that
#     hardens before it installs, and then let this handle the dev environment.
#
# Usage:
#   bash <(curl -fsSL .../server-dev.sh)                       # dev environment
#   bash <(curl -fsSL .../server-dev.sh) --ai                  # also install Claude Code + Codex CLIs
#   bash <(curl -fsSL .../server-dev.sh) --pnpm                # also install pnpm
#   bash <(curl -fsSL .../server-dev.sh) --agent-setup         # +CLIs, plugins, skills, settings, Jira MCP
#   bash <(curl -fsSL .../server-dev.sh) --chrome              # headless Chrome/Chromium for browser automation
#
# (When piping via process substitution, flags go after the closing paren.)
#
# pipefail matters more here than anywhere else in this repo: almost every
# install step is `curl ... | sudo tee` or `curl ... | bash`. With `set -e`
# alone a pipeline reports the status of its LAST command, so a 404 or a DNS
# blip on the curl still exits 0 — tee cheerfully writes an empty keyring and
# bash cheerfully runs an empty script. The run then continues and fails much
# later somewhere unrelated.
set -e
set -o pipefail

REPO_URL="https://github.com/nathanialhenniges/dotfiles.git"
RAW_URL="https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/server-dev.sh"
DOTFILES_DIR="$HOME/dotfiles"

# Parse flags.
# Help text is embedded, not scraped from "$0" — under the documented
# `bash <(curl ...)` invocation $0 is a /dev/fd pipe that is already consumed,
# so self-grepping printed nothing at all.
usage() {
  cat <<'USAGE'
server-dev.sh — bootstrap a Linux dev server: zsh env + dev tooling.

THIS SCRIPT DOES NOT HARDEN THE MACHINE. No sshd changes, no firewall, no
fail2ban, no sysctl, no unattended upgrades. On a bare internet-facing host it
leaves password SSH on and every port open, and it installs Docker, whose
published ports bypass a host firewall even where one exists.

That is deliberate. This is a dotfiles repo — shell config, editor config, dev
tooling. Who can reach a server is server devops; it belongs with the
infrastructure code that owns those machines, not in a public dotfiles repo.
Hardening used to live here and was moved out.

Run this on a box that is ALREADY secured: behind a VPN, a bastion, a cloud
security group, or provisioned by something that hardened it first.

Usage:
  bash <(curl -fsSL .../server-dev.sh) [flags]

Flags:
  --ai                      install Claude Code + Codex CLIs (+ bubblewrap sandbox)
  --pnpm                    install pnpm
  --agent-setup             implies --ai; also installs plugins into both CLIs,
                            the skills pack, curated settings, and pre-registers
                            the Atlassian (Jira) MCP
  --agent-setup-only        run ONLY the --agent-setup step on a box this script
                            already provisioned — no apt, no Docker, no shell
                            changes. For re-running plugin installs that failed
                            (the run prints which ones) without a full rebuild.
  --chrome                  install headless Chrome/Chromium for browser automation
  -h, --help                show this help

Always applied: dev toolchain (fnm + latest LTS Node, Docker, gh, direnv, bun,
go, build-essential, jq, eza, btop), plus ~/Developer and ~/Downloads.
(--agent-setup-only skips all of that by design.)
USAGE
}

INSTALL_AI=""
INSTALL_PNPM=""
AGENT_SETUP=""
AGENT_SETUP_ONLY=""
INSTALL_CHROME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --ai)          INSTALL_AI=1; shift ;;
    --pnpm)        INSTALL_PNPM=1; shift ;;
    --agent-setup) AGENT_SETUP=1; shift ;;
    # Implies --agent-setup: asking for only that step is asking for that step.
    --agent-setup-only) AGENT_SETUP=1; AGENT_SETUP_ONLY=1; shift ;;
    --chrome)      INSTALL_CHROME=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    --hostname|--hostname=*|--no-firewall)
      # Moved out with the hardening. Fail loudly rather than silently ignoring
      # a flag someone's muscle memory (or an old script) still passes — being
      # quietly dropped is how you end up believing a box was hardened.
      echo "$1 was removed from server-dev.sh — hostname and firewall are now" >&2
      echo "handled by the provisioning script that hardens the box, not by" >&2
      echo "dotfiles. This script installs the dev environment only." >&2
      exit 1 ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Try: --ai, --pnpm, --agent-setup, --agent-setup-only, --chrome, --help" >&2
      exit 1 ;;
  esac
done

echo "==> Dev server bootstrap starting..."

# Clone dotfiles repo (skip if already exists) — must happen before we can
# source the shared bootstrap lib below.
if [[ -d "$DOTFILES_DIR" ]]; then
  echo "==> Dotfiles repo already exists, pulling latest..."
  git -C "$DOTFILES_DIR" pull
else
  echo "==> Cloning dotfiles repo..."
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# shellcheck source=lib/bootstrap.sh
source "$DOTFILES_DIR/lib/bootstrap.sh"

# ── Dev additions (Linux only) ───────────────────────────────────────────────

create_home_dirs() {
  log "Creating home directories..."
  mkdir -p "$HOME/Developer" "$HOME/Downloads"
  substep "~/Developer, ~/Downloads ready"
}

install_dev_packages() {
  log "Installing dev packages..."
  sudo apt update
  sudo apt install -y build-essential jq direnv btop
  # eza only ships in newer Ubuntu (24.04+) repos — tolerate its absence.
  sudo apt install -y eza || substep "eza not in apt, skipping"

  # GitHub CLI via GitHub's official apt repo (not in default repos).
  if ! command -v gh &>/dev/null; then
    substep "Adding GitHub CLI apt repo..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt update
    sudo apt install -y gh
  fi
}

install_go() {
  # ponytail: distro Go can lag; upgrade path = official tarball from go.dev/dl.
  log "Installing Go..."
  sudo apt install -y golang-go
}

install_bun() {
  if ! command -v bun &>/dev/null; then
    log "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
  fi
}

install_fnm_node() {
  # apt has no fnm — use the official installer (drops it in ~/.local/share/fnm).
  if ! command -v fnm &>/dev/null && [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
    log "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash
  fi
  export PATH="$HOME/.local/share/fnm:$PATH"
  command -v fnm &>/dev/null || { substep "fnm not found — skipping Node"; return; }

  log "Installing latest LTS Node.js via fnm..."
  fnm install --lts
  # Set the default BEFORE activating, so `fnm env` picks it up in this shell.
  # `lts-latest` is the alias fnm creates for the newest LTS it installed.
  fnm default lts-latest
  eval "$(fnm env)"
  fnm use default &>/dev/null || true
  substep "Node.js $(node --version 2>/dev/null) (LTS) set as default"
}

# Put an ALREADY-installed fnm/Node on PATH, installing and upgrading nothing.
#
# --agent-setup-only skips install_fnm_node, and on a provisioned box the
# toolchain is activated from .zshrc — so under bash `claude` and `node` do not
# resolve even though they are installed. Without this, agent_setup would decide
# the CLIs are missing and reinstall them, which is the opposite of "only".
activate_existing_node() {
  export PATH="$HOME/.local/share/fnm:$PATH"
  if command -v fnm &>/dev/null; then
    eval "$(fnm env)" || true
    fnm use default &>/dev/null || true
  fi
}

# Echo an npm-global command: direct npm, else via fnm's default node, else empty.
npm_global_cmd() {
  if command -v npm &>/dev/null; then
    echo "npm"
  elif command -v fnm &>/dev/null; then
    echo "fnm exec --using=default npm"
  fi
}

install_pnpm() {
  local npm_cmd; npm_cmd="$(npm_global_cmd)"
  if [[ -n "$npm_cmd" ]]; then
    log "Installing pnpm..."
    $npm_cmd install -g pnpm
    substep "pnpm installed globally"
  else
    substep "npm not found — skipping pnpm install"
  fi
}

install_ai_clis() {
  # npm globals — need Node. install_fnm_node activates the default version, but
  # npm_global_cmd falls back to `fnm exec` if PATH activation didn't stick.
  local npm_cmd; npm_cmd="$(npm_global_cmd)"
  if [[ -n "$npm_cmd" ]]; then
    log "Installing AI CLIs (Claude Code, Codex)..."
    # Codex uses bubblewrap (bwrap) for its Linux sandbox.
    sudo apt install -y bubblewrap
    $npm_cmd install -g @anthropic-ai/claude-code @openai/codex
    substep "claude-code + codex installed globally (+ bubblewrap sandbox)"
  else
    substep "npm not found — skipping Claude Code / Codex install"
  fi
}

install_docker() {
  if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    substep "Added $USER to the docker group (log out/in to take effect)"
  fi
}

# GitHub-shorthand marketplaces + plugins, shared by both Claude Code and Codex
# (both take `plugin marketplace add owner/repo` and `plugin (install|add)
# name@marketplace`, so the same set installs into each).
#
# Entries are `owner/repo=alias`. The alias is NOT derived from the repo name —
# it comes from the "name" field in that repo's .claude-plugin/marketplace.json,
# and the two differ often enough to matter: expo/skills registers as
# `expo-plugins`. Writing the alias down here is what lets agent_plugin_preflight
# catch an AGENT_PLUGINS entry pointing at a marketplace nothing registers.
AGENT_MARKETPLACES=(
  anthropics/claude-plugins-official=claude-plugins-official
  JuliusBrussee/caveman=caveman
  DietrichGebert/ponytail=ponytail
  mksglu/context-mode=context-mode
  elvismdev/claude-wordpress-skills=claude-wordpress-skills
  # KNOWN BROKEN UPSTREAM (checked 2026-07-29): adding this fails, and so does
  # every expo plugin under it. expo/skills carries a submodule `eval-harness`
  # pointing at github.com/expo/eval-experiments, which is private or gone, and
  # the CLI clones marketplaces with submodules — so the clone aborts and the
  # marketplace never registers. Nothing to fix on our side; kept here so it
  # starts working the moment upstream drops the submodule. The run now says so
  # out loud instead of shrugging.
  expo/skills=expo-plugins
)
AGENT_PLUGINS=(
  atlassian@claude-plugins-official
  coderabbit@claude-plugins-official
  frontend-design@claude-plugins-official
  swift-lsp@claude-plugins-official
  caveman@caveman
  ponytail@ponytail
  context-mode@context-mode
  claude-wordpress-skills@claude-wordpress-skills
  # `expo-deployment` and `upgrading-expo` are deprecated upstream aliases that
  # both resolve to ./plugins/expo — installing them got you the same plugin
  # twice under two dead names.
  expo@expo-plugins
)

# Every failed marketplace/plugin step, replayed at the end of agent_setup.
AGENT_SETUP_FAILURES=()

# Runs one plugin/marketplace command and reports what actually happened.
#
# The old form was `cmd &>/dev/null || substep "... (already installed or
# unavailable)"`, which collapsed "no-op, you already have this" and "this is
# broken and you do not have it" into one reassuring line. That is how the expo
# marketplace failure survived a whole provisioning run on chi-01: the add
# failed, both installs under it failed as a consequence, and the log said
# nothing a person would stop on. Exit status alone can't separate the two
# either — both are non-zero — so match the output.
agent_try() { # <description> <command...>
  local what=$1; shift
  # `rc`, not `status` — that name is a read-only special in zsh, and these
  # helpers get eval'd out of this file by tests and by hand.
  local out rc=0 flat
  out=$("$@" 2>&1) || rc=$?
  if (( rc == 0 )); then
    substep "$what"
  elif grep -qiE 'already (installed|added|exists|present)|is already' <<<"$out"; then
    substep "$what (already present)"
  else
    # These tools spew a whole git clone transcript, and the reason lands at the
    # END of it — a naive head-of-output would show a progress bar and a temp
    # path, which hides the error about as well as /dev/null did. Drop the
    # progress noise, keep the last few lines, flatten, cap.
    flat=$(printf '%s\n' "$out" \
      | grep -avE 'Updating files|Receiving objects|Resolving deltas|Cloning into|remote: (Counting|Compressing|Enumerating|Total)' \
      | tail -n 3 | tr '\n' ' ' | tr -s ' ') || flat=$(tr '\n' ' ' <<<"$out")
    substep "FAILED  $what"
    substep "        ${flat:0:240}"
    AGENT_SETUP_FAILURES+=("$what")
  fi
}

# Catches an AGENT_PLUGINS entry whose @marketplace nothing in
# AGENT_MARKETPLACES registers. That mismatch is unfixable at install time and
# silent at runtime, so check it before touching the box.
agent_plugin_preflight() {
  local known=" " m p rc=0
  for m in "${AGENT_MARKETPLACES[@]}"; do known+="${m##*=} "; done
  for p in "${AGENT_PLUGINS[@]}"; do
    if [[ "$known" != *" ${p##*@} "* ]]; then
      substep "BUG: $p names marketplace '${p##*@}', which AGENT_MARKETPLACES never registers"
      rc=1
    fi
  done
  return $rc
}

install_chrome() {
  # Headless browser for automation/screenshots (Playwright, Puppeteer,
  # chrome-devtools-mcp, etc.). Google Chrome is amd64-only on Linux; fall back
  # to Chromium on other arches.
  if command -v google-chrome-stable &>/dev/null \
    || command -v chromium &>/dev/null || command -v chromium-browser &>/dev/null; then
    substep "Chrome/Chromium already installed"
    return
  fi
  local arch; arch="$(dpkg --print-architecture)"
  if [[ "$arch" == "amd64" ]]; then
    log "Installing Google Chrome (headless)..."
    sudo apt install -y gnupg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
      | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
    sudo apt update
    sudo apt install -y google-chrome-stable fonts-liberation
    substep "google-chrome-stable installed ($(google-chrome-stable --version 2>/dev/null))"
  else
    log "Installing Chromium (headless, $arch)..."
    sudo apt install -y chromium fonts-liberation 2>/dev/null \
      || sudo apt install -y chromium-browser fonts-liberation
    substep "chromium installed"
  fi
}

agent_setup() {
  # Needs the Claude Code CLI — install the AI CLIs if they're not here yet.
  command -v claude &>/dev/null || install_ai_clis
  local agent_dir="$DOTFILES_DIR/config/agent"

  # Curated Claude Code settings (model, permissions, plugins) — no machine-
  # specific hooks/statusline paths. Written first so plugins load declaratively.
  log "Installing Claude Code settings + skills..."
  mkdir -p "$HOME/.claude/skills"
  [[ -f "$HOME/.claude/settings.json" ]] && cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.backup"
  cp "$agent_dir/claude/settings.json" "$HOME/.claude/settings.json"
  cp -R "$agent_dir/claude/skills/." "$HOME/.claude/skills/"
  substep "settings.json + $(ls -1 "$agent_dir/claude/skills" | wc -l | tr -d ' ') skills installed"

  local m p
  agent_plugin_preflight || substep "^ fix the arrays in server-dev.sh; installing the rest anyway"

  # Claude Code plugins — add each marketplace, then install each plugin.
  if command -v claude &>/dev/null; then
    log "Adding Claude Code plugin marketplaces..."
    for m in "${AGENT_MARKETPLACES[@]}"; do
      agent_try "claude marketplace ${m%%=*}" claude plugin marketplace add "${m%%=*}"
    done
    log "Installing Claude Code plugins..."
    for p in "${AGENT_PLUGINS[@]}"; do
      agent_try "claude plugin $p" claude plugin install "$p"
    done
    # Pre-register the Atlassian (Jira) MCP — OAuth login is manual, see docs.
    agent_try "atlassian MCP" \
      claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp
  else
    substep "claude CLI missing — skipped plugins + Jira MCP"
  fi

  # Codex: Linux-safe config.toml (drops macOS-only servers).
  log "Installing Codex config..."
  mkdir -p "$HOME/.codex"
  [[ -f "$HOME/.codex/config.toml" ]] && cp "$HOME/.codex/config.toml" "$HOME/.codex/config.toml.backup"
  cp "$agent_dir/codex/config.toml" "$HOME/.codex/config.toml"

  # Codex plugins — same Git marketplaces + plugin set as Claude (Codex takes
  # `plugin marketplace add owner/repo` and `plugin add name@marketplace`).
  if command -v codex &>/dev/null; then
    log "Adding Codex plugin marketplaces (same as Claude)..."
    for m in "${AGENT_MARKETPLACES[@]}"; do
      agent_try "codex marketplace ${m%%=*}" codex plugin marketplace add "${m%%=*}"
    done
    log "Installing Codex plugins..."
    for p in "${AGENT_PLUGINS[@]}"; do
      agent_try "codex plugin $p" codex plugin add "$p"
    done
  else
    substep "codex CLI missing — skipped codex plugins"
  fi

  substep "Agent setup done. Jira/Atlassian needs a one-time OAuth login —"
  substep "  see $DOTFILES_DIR/docs/jira-mcp-setup.md (claude: /mcp; codex: first run)."

  if (( ${#AGENT_SETUP_FAILURES[@]} > 0 )); then
    echo ""
    echo "==> ${#AGENT_SETUP_FAILURES[@]} agent-setup step(s) FAILED — the rest of the box is fine:"
    printf '      - %s\n' "${AGENT_SETUP_FAILURES[@]}"
    echo "    None of this needs you to be logged in — these are git clones, not"
    echo "    API calls. To retry just this step, without rebuilding the box:"
    echo "      bash <(curl -fsSL $RAW_URL) --agent-setup-only"
    echo "    Or re-run one by hand to see its full error, e.g."
    echo "      claude plugin marketplace add <owner/repo>"
  fi
}

# ── Run ──────────────────────────────────────────────────────────────────────

detect_os
if [[ "$OS" == "Darwin" ]]; then
  echo "==> server-dev.sh is Linux-only. On macOS use ./install.sh (Brewfile + OrbStack)."
  exit 1
fi

# --agent-setup-only: the agent step and nothing else. No apt, no Docker, no
# chsh, no dotfile copies. Meant for a box this script already provisioned —
# typically to retry plugin installs that failed the first time.
if [[ -n "$AGENT_SETUP_ONLY" ]]; then
  activate_existing_node
  agent_setup
  echo ""
  echo "==> Agent setup done. Nothing else was touched (--agent-setup-only)."
  exit 0
fi

# Home directory layout
create_home_dirs

# Base environment (shared with server.sh)
install_base_packages
install_oh_my_zsh
install_zsh_plugins
install_oh_my_posh
copy_configs "$DOTFILES_DIR/config/server"

# Dev tooling
install_dev_packages
install_go
install_bun
install_fnm_node
[[ -n "$INSTALL_PNPM" ]] && install_pnpm
[[ -n "$INSTALL_AI" ]] && install_ai_clis
[[ -n "$AGENT_SETUP" ]] && agent_setup
[[ -n "$INSTALL_CHROME" ]] && install_chrome
install_docker

# Cloud images create the default user with a locked password, and chsh
# authenticates through PAM against it — so this can fail on a perfectly good
# box. Under `set -e` that used to kill the script here, taking the Next-steps
# block with it, including the one line that tells you to verify key login
# before disconnecting. The least important step was destroying the most
# important safety net.
set_default_shell || substep "chsh failed — run: sudo chsh -s \$(which zsh) $(id -un)"

echo ""
echo "==> Done! Next steps:"
echo "    - Open a SECOND SSH session NOW to confirm key login still works"
echo "      before you disconnect this one (sshd was just reloaded)."
echo "    - Reconnect your SSH session to start using zsh + fnm."
echo "    - Log out and back in for Docker group membership to apply."
echo "    - Run 'gh auth login' to authenticate the GitHub CLI."
echo "      To scope gh to a single org, use a fine-grained PAT:"
echo "      gh auth login --with-token < token.txt   (see README)"
if [[ -n "$AGENT_SETUP" ]]; then
echo "    - Run 'claude' once to log in to your Claude Code account. Plugins are"
echo "      already installed — they are git clones and need no login — so this"
echo "      is only about signing in. To redo the plugin step later (say, after"
echo "      a marketplace that was down comes back), re-run just that step:"
echo "      bash <(curl -fsSL $RAW_URL) --agent-setup-only"
fi
echo "    - Reach dev app ports from your laptop with SSH forwarding, e.g.:"
echo "      ssh -L 3000:localhost:3000 $USER@<this-box>   (see README)"
