#!/bin/bash
# Bootstrap a remote Linux dev server: clean zsh env + dev tooling + hardening.
# Installs everything server.sh does, plus fnm/Node, Docker, and dev CLIs
# (gh, direnv, bun, go, build-essential, jq, eza, btop), then applies base
# hardening (key-only sshd, sysctl, fail2ban, auto security upgrades, and UFW
# SSH-only unless --no-firewall).
#
# Usage:
#   bash <(curl -fsSL .../server-dev.sh)                       # no hostname change
#   bash <(curl -fsSL .../server-dev.sh) --hostname foo        # set hostname to "foo"
#   bash <(curl -fsSL .../server-dev.sh) --hostname random     # random wolf-themed hostname
#   bash <(curl -fsSL .../server-dev.sh) --ai                  # also install Claude Code + Codex CLIs
#   bash <(curl -fsSL .../server-dev.sh) --pnpm                # also install pnpm
#   bash <(curl -fsSL .../server-dev.sh) --agent-setup         # +CLIs, plugins, skills, settings, Jira MCP
#   bash <(curl -fsSL .../server-dev.sh) --chrome              # headless Chrome/Chromium for browser automation
#   bash <(curl -fsSL .../server-dev.sh) --no-firewall         # skip UFW (a cloud firewall already fronts the host)
#
# (When piping via process substitution, flags go after the closing paren.)
set -e

REPO_URL="https://github.com/nathanialhenniges/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# Wolf-themed hostnames for --hostname random.
WOLF_HOSTNAMES=(fenrir lupus luna shadow ghost timber sirius akela balto \
  storm aspen grey nanuk yuki koda tundra vesper draco onyx rowan)

# Parse flags.
# Help text is embedded, not scraped from "$0" — under the documented
# `bash <(curl ...)` invocation $0 is a /dev/fd pipe that is already consumed,
# so self-grepping printed nothing at all.
usage() {
  cat <<'USAGE'
server-dev.sh — bootstrap a Linux dev server: zsh env + dev tooling + hardening.

Usage:
  bash <(curl -fsSL .../server-dev.sh) [flags]

Flags:
  --hostname <name|random>  set hostname. Accepts a short name or an FQDN
                            (host.example.com sets the short name and writes
                            "127.0.1.1  fqdn short" the way Debian expects).
                            random = wolf-themed. Omit to keep current.
  --ai                      install Claude Code + Codex CLIs (+ bubblewrap sandbox)
  --pnpm                    install pnpm
  --agent-setup             implies --ai; also installs plugins into both CLIs,
                            the skills pack, curated settings, and pre-registers
                            the Atlassian (Jira) MCP
  --chrome                  install headless Chrome/Chromium for browser automation
  --no-firewall             skip UFW entirely. Only for hosts already behind a
                            provider firewall (security groups, VPC rules) that
                            you can edit without logging into the box.
  -h, --help                show this help

Always applied: dev toolchain (fnm + latest LTS Node, Docker, gh, direnv, bun,
go, build-essential, jq, eza, btop), ~/Developer and ~/Downloads, and base
hardening (key-only sshd, sysctl, fail2ban, unattended upgrades) plus UFW
default-deny with SSH-only unless --no-firewall is given.

Password auth is only disabled once ~/.ssh/authorized_keys exists for the
running user, so a keyless box is never locked out.

Why --no-firewall exists: a firewall you can only edit from inside the box is
also the one that can lock you out of it. Where the provider offers an
out-of-band firewall, letting that be the single control keeps the way back in
reachable from a browser. It is opt-in because on a host with no such firewall
in front of it, skipping UFW leaves nothing at all.
USAGE
}

HOSTNAME_ARG=""
INSTALL_AI=""
INSTALL_PNPM=""
AGENT_SETUP=""
INSTALL_CHROME=""
SKIP_FIREWALL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname)
      # "${2:-random}" used to swallow the NEXT FLAG as the hostname:
      # `--hostname --ai` dropped --ai and then failed inside hostnamectl.
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "--hostname needs a value (a name, or 'random')" >&2; exit 1
      fi
      HOSTNAME_ARG="$2"; shift 2 ;;
    --hostname=*)
      HOSTNAME_ARG="${1#*=}"
      [[ -n "$HOSTNAME_ARG" ]] || { echo "--hostname= needs a value" >&2; exit 1; }
      shift ;;
    --ai)          INSTALL_AI=1; shift ;;
    --pnpm)        INSTALL_PNPM=1; shift ;;
    --agent-setup) AGENT_SETUP=1; shift ;;
    --chrome)      INSTALL_CHROME=1; shift ;;
    --no-firewall) SKIP_FIREWALL=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Try: --hostname <name|random>, --ai, --pnpm, --agent-setup, --chrome, --no-firewall, --help" >&2
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

set_hostname() {
  local name="$1"
  if [[ "$name" == "random" ]]; then
    name="${WOLF_HOSTNAMES[$RANDOM % ${#WOLF_HOSTNAMES[@]}]}"
  fi

  # Accept either a short name (devbox) or an FQDN (devbox.example.com).
  # Debian/Ubuntu want the FQDN first on the 127.0.1.1 line, then the short
  # name — `hostname -f` reads that line, so getting the order wrong is how you
  # end up with a box that cannot resolve its own fully-qualified name.
  local fqdn short
  fqdn="$name"
  short="${name%%.*}"

  # RFC 1123 labels: alphanumeric and hyphen, no leading/trailing hyphen, <=63
  # chars each. hostnamectl rejects bad names anyway, but it does it AFTER
  # /etc/hosts might already have been touched, and under `set -e` that aborts
  # the whole run with an opaque error.
  if [[ ! "$short" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
    echo "Invalid hostname '$short' — letters, digits and hyphens only," >&2
    echo "must not start or end with a hyphen, 63 characters max." >&2
    exit 1
  fi

  log "Setting hostname to '$short'..."
  sudo hostnamectl set-hostname "$short"

  # Cloud images run cloud-init with preserve_hostname: false, which rewrites
  # the hostname AND /etc/hosts on every boot. Without this the rename silently
  # reverts at the first reboot and the box answers to its old name again.
  if [[ -d /etc/cloud ]]; then
    sudo mkdir -p /etc/cloud/cloud.cfg.d
    printf 'preserve_hostname: true\n' \
      | sudo tee /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg >/dev/null
    substep "cloud-init told to preserve the hostname across reboots"
  fi

  # 127.0.0.1 must stay localhost; the system's own name belongs on 127.0.1.1.
  # Debian policy uses that second loopback address precisely so the hostname
  # keeps resolving on a machine with no permanent IP.
  grep -qE '^127\.0\.0\.1[[:space:]]+.*\blocalhost\b' /etc/hosts \
    || printf '127.0.0.1\tlocalhost\n' | sudo tee -a /etc/hosts >/dev/null

  local line
  if [[ "$fqdn" == *.* ]]; then
    line=$(printf '127.0.1.1\t%s %s' "$fqdn" "$short")
  else
    line=$(printf '127.0.1.1\t%s' "$short")
  fi

  # Rewrite via awk rather than `sed s///` — the replacement text is
  # user-supplied and sed would treat & and \ in it as metacharacters. mktemp
  # rather than a $$-predictable path, since /tmp is world-writable.
  local tmp
  tmp=$(mktemp) || { echo "mktemp failed" >&2; exit 1; }
  awk -v repl="$line" \
    '/^127\.0\.1\.1/ { if (!done) { print repl; done=1 } ; next }
     { print }
     END { if (!done) print repl }' /etc/hosts > "$tmp"
  # cp onto the existing file keeps /etc/hosts own mode and ownership.
  sudo cp "$tmp" /etc/hosts
  rm -f "$tmp"

  substep "Hostname set to '$short'$([[ "$fqdn" == *.* ]] && echo " (FQDN $fqdn)")"
  substep "/etc/hosts: $(grep '^127\.0\.1\.1' /etc/hosts | head -1)"
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
AGENT_MARKETPLACES=(
  anthropics/claude-plugins-official
  JuliusBrussee/caveman
  DietrichGebert/ponytail
  mksglu/context-mode
  elvismdev/claude-wordpress-skills
  expo/skills
  tsanva/cc-discord-presence
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
  expo-deployment@expo-plugins
  upgrading-expo@expo-plugins
)

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
  # Claude Code plugins — add each marketplace, then install each plugin.
  if command -v claude &>/dev/null; then
    log "Adding Claude Code plugin marketplaces..."
    for m in "${AGENT_MARKETPLACES[@]}"; do
      claude plugin marketplace add "$m" &>/dev/null || substep "claude marketplace $m (already added or unavailable)"
    done
    log "Installing Claude Code plugins..."
    for p in "${AGENT_PLUGINS[@]}"; do
      claude plugin install "$p" &>/dev/null || substep "claude plugin $p (already installed or unavailable)"
    done
    # Pre-register the Atlassian (Jira) MCP — OAuth login is manual, see docs.
    claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp &>/dev/null \
      || substep "atlassian MCP (already added or unavailable)"
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
      codex plugin marketplace add "$m" &>/dev/null || substep "codex marketplace $m (already added or unavailable)"
    done
    log "Installing Codex plugins..."
    for p in "${AGENT_PLUGINS[@]}"; do
      codex plugin add "$p" &>/dev/null || substep "codex plugin $p (unavailable — install manually)"
    done
  else
    substep "codex CLI missing — skipped codex plugins"
  fi

  substep "Agent setup done. Jira/Atlassian needs a one-time OAuth login —"
  substep "  see $DOTFILES_DIR/docs/jira-mcp-setup.md (claude: /mcp; codex: first run)."
}

# ── Semi-lockdown hardening (always runs) ────────────────────────────────────
# Ports the BASE hardening from mrdemonwolf/server-setup (ssh, sysctl, firewall,
# unattended-upgrades). Assumes the sudo account + your SSH key already exist —
# this script only hardens, it does NOT create the user.

install_security_packages() {
  log "Installing security packages..."
  sudo apt install -y ufw fail2ban ca-certificates gnupg
}

# Whether $1's authorized_keys holds a key sshd would actually accept.
# `[[ -s ]]` is not enough: a file containing "# paste your key here" is
# non-empty and fails ssh-keygen, and StrictModes makes sshd ignore the file
# entirely if the home or .ssh dir is group/world-writable. Both cases used to
# read as "key present" and disable password auth on a box with no way in.
has_usable_ssh_key() {
  local home="$1" keys="$1/.ssh/authorized_keys"
  [[ -s "$keys" ]] || return 1
  # ssh-keygen -l happily fingerprints a PRIVATE key too, so it alone would
  # accept a file with a private key pasted in by mistake — which sshd then
  # ignores. Require an actual public-key line as well.
  grep -qE '^[[:space:]]*(ssh-(rsa|ed25519|dss)|ecdsa-sha2-[a-z0-9-]+|sk-(ssh-ed25519|ecdsa-sha2-nistp256)@openssh\.com)[[:space:]]+AAAA' "$keys" || return 1
  ssh-keygen -l -f "$keys" >/dev/null 2>&1 || return 1
  # StrictModes: sshd refuses group/world-writable $HOME or ~/.ssh.
  local perms
  for d in "$home" "$home/.ssh"; do
    perms=$(stat -c '%a' "$d" 2>/dev/null) || return 0
    [[ "${perms: -2}" =~ ^[0-5][0-5]$ ]] || return 1
  done
  return 0
}

harden_ssh() {
  log "Hardening sshd..."
  # Ubuntu's stock sshd_config Includes /etc/ssh/sshd_config.d/*.conf as its
  # FIRST directive, and sshd keeps the first value it sees for each keyword.
  # Cloud images ship 50-cloud-init.conf with `PasswordAuthentication yes`, so
  # a 99- drop-in silently loses every conflict — the box kept accepting
  # passwords while this script reported it had hardened. 00- wins instead, and
  # the sshd -T check at the end verifies it rather than assuming.
  local dropin="/etc/ssh/sshd_config.d/00-hardening.conf"
  sudo rm -f /etc/ssh/sshd_config.d/99-hardening.conf

  # Act on the account that will actually log in. Under `sudo bash <(curl ...)`
  # $HOME is /root and $USER is root, so the old check inspected root's keys and
  # could disable password auth for a keyless human.
  local target_user target_home
  target_user="${SUDO_USER:-$(id -un)}"
  target_home=$(getent passwd "$target_user" | cut -d: -f6)
  [[ -n "$target_home" ]] || target_home="$HOME"

  # Lockout guard. Password auth and root-password login are only withdrawn
  # once a key that sshd will honour is in place for that account.
  local password_line root_line
  if has_usable_ssh_key "$target_home"; then
    password_line="PasswordAuthentication no"
    root_line="PermitRootLogin prohibit-password"
    substep "Key verified for $target_user — disabling password auth"
  else
    password_line="# PasswordAuthentication left ON — no usable key for $target_user"
    # PermitRootLogin used to be written unconditionally. On a provider that
    # gives you a root password and no key, that alone was a hard lockout.
    root_line="# PermitRootLogin left at default — no usable key for $target_user"
    substep "WARNING: no usable SSH key for $target_user ($target_home/.ssh/authorized_keys)."
    substep "         Password auth and root login left ENABLED — this box is NOT hardened."
    substep "         Install a key (check perms: chmod 700 ~/.ssh, 600 authorized_keys),"
    substep "         then re-run to lock it down."
  fi

  # Mirrors roles/ssh/templates/sshd_config.j2.
  sudo tee "$dropin" >/dev/null <<EOF
# Managed by server-dev.sh — mirrors mrdemonwolf/server-setup ssh role.
$root_line
$password_line
PubkeyAuthentication yes
X11Forwarding no
PrintLastLog no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
  sudo chmod 0644 "$dropin"

  # Validate before restarting — a bad config must never take down sshd.
  if ! sudo sshd -t; then
    substep "ERROR: sshd -t failed — removing drop-in, sshd left unchanged"
    sudo rm -f "$dropin"
    return 1
  fi

  # A failed restart used to abort the whole script under `set -e`, leaving the
  # drop-in on disk to take effect unsupervised at the next boot.
  if ! sudo systemctl reload ssh 2>/dev/null && ! sudo systemctl restart ssh; then
    substep "ERROR: sshd reload/restart failed — removing drop-in and reverting"
    sudo rm -f "$dropin"
    sudo systemctl restart ssh || true
    return 1
  fi

  # Report what sshd RESOLVED, not what we wrote. This is the check that would
  # have caught the 99- vs 50-cloud-init ordering bug.
  local eff
  eff=$(sudo sshd -T 2>/dev/null | grep -E '^(passwordauthentication|permitrootlogin|port) ' | tr '\n' ' ')
  substep "sshd reloaded — effective: ${eff:-unknown}"
  if [[ "$password_line" == "PasswordAuthentication no" && "$eff" != *"passwordauthentication no"* ]]; then
    substep "WARNING: password auth is STILL ENABLED — another drop-in in"
    substep "         /etc/ssh/sshd_config.d/ is overriding this one. Check it."
  fi
}

harden_sysctl() {
  log "Applying sysctl kernel hardening..."
  # Verbatim from roles/sysctl/files/99-hardening.conf.
  sudo tee /etc/sysctl.d/99-hardening.conf >/dev/null <<'EOF'
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Swap tuning (low swappiness — only use swap when really needed)
vm.swappiness = 10
EOF
  # Containers (LXC/OpenVZ/Proxmox) expose some of these keys read-only, so a
  # non-zero exit here is expected there. Under `set -e` it used to abort the
  # run BEFORE the firewall, fail2ban and sshd hardening — a box that ran the
  # hardening script and got none of it.
  sudo sysctl --system >/dev/null 2>&1 \
    || substep "some sysctl keys unsupported (container?) — continuing"
  substep "sysctl hardening applied"
}

harden_firewall() {
  log "Configuring UFW (SSH only)..."
  # Ask sshd which ports it actually listens on rather than assuming 22. A
  # pre-existing `Port 2222` from a provider drop-in used to survive here, and
  # `ufw allow 22` then locked the box on the NEXT connect — the live session
  # stayed up on the ESTABLISHED rule, so the run looked like it worked.
  local ports
  ports=$(sudo sshd -T 2>/dev/null | awk '/^port /{print $2}')
  [[ -n "$ports" ]] || ports=22

  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  # Allow SSH BEFORE enabling, or enabling drops the current session.
  local p
  for p in $ports; do
    sudo ufw allow "$p"/tcp comment 'SSH'
  done
  sudo ufw --force enable
  substep "UFW enabled — inbound denied except SSH on: $(echo $ports | tr '\n' ' ')"
  substep "NOTE: Docker publishes past UFW. A container run with -p is reachable"
  substep "      regardless of this. Bind to 127.0.0.1 and use 'ssh -L'."
}

enable_unattended_upgrades() {
  log "Enabling unattended security upgrades..."
  sudo apt install -y unattended-upgrades apt-listchanges
  # Verbatim from roles/unattended-upgrades.
  sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
  sudo tee /etc/apt/apt.conf.d/50unattended-upgrades >/dev/null <<'EOF'
Unattended-Upgrade::Allowed-Origins {
  "${distro_id}:${distro_codename}";
  "${distro_id}:${distro_codename}-security";
  "${distro_id}ESMApps:${distro_codename}-apps-security";
  "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
  sudo systemctl enable --now unattended-upgrades
  substep "unattended-upgrades enabled (security origins, no auto-reboot)"
}

enable_fail2ban() {
  log "Enabling fail2ban..."
  # Default distro jail already protects sshd — no custom jail.local needed.
  sudo systemctl enable --now fail2ban
  substep "fail2ban enabled (default sshd jail)"
}

harden_server() {
  install_security_packages
  harden_sysctl
  if [[ -n "$SKIP_FIREWALL" ]]; then
    # --no-firewall skips CONFIGURING ufw; it does not disable an already-active
    # one. Saying "nothing is filtering this host" to someone whose earlier run
    # enabled UFW sends them hunting the wrong layer when a port stays shut.
    if sudo ufw status 2>/dev/null | grep -q '^Status: active'; then
      substep "UFW SKIPPED (--no-firewall) but UFW is ALREADY ACTIVE from an"
      substep "       earlier run and is still enforcing. This flag did not turn"
      substep "       it off — run 'sudo ufw disable' if that is what you meant."
    else
      substep "UFW SKIPPED (--no-firewall) — inbound is only filtered by whatever"
      substep "       sits in front of this host. Verify with nmap from off-box;"
      substep "       'ufw status' on an unconfigured host proves nothing."
    fi
  else
    harden_firewall
  fi
  enable_unattended_upgrades
  enable_fail2ban
  # SSH last: if it fails validation it aborts here without having skipped the
  # firewall/fail2ban protection above.
  harden_ssh
}

# ── Run ──────────────────────────────────────────────────────────────────────

detect_os
if [[ "$OS" == "Darwin" ]]; then
  echo "==> server-dev.sh is Linux-only. On macOS use ./install.sh (Brewfile + OrbStack)."
  exit 1
fi

# Hostname first, so the new name shows up everywhere downstream.
[[ -n "$HOSTNAME_ARG" ]] && set_hostname "$HOSTNAME_ARG"

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

# Semi-lockdown hardening
harden_server

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
echo "    - Reach dev app ports from your laptop with SSH forwarding, e.g.:"
echo "      ssh -L 3000:localhost:3000 $USER@<this-box>   (see README)"
