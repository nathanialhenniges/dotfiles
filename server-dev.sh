#!/bin/bash
# Bootstrap a remote Linux dev server: clean zsh env + dev tooling + hardening.
# Installs everything server.sh does, plus fnm/Node, Docker, and dev CLIs
# (gh, direnv, bun, go, build-essential, jq, eza, btop), then applies base
# hardening (key-only sshd, UFW SSH-only, sysctl, fail2ban, auto security
# upgrades).
#
# Usage:
#   bash <(curl -fsSL .../server-dev.sh)                       # no hostname change
#   bash <(curl -fsSL .../server-dev.sh) --hostname foo        # set hostname to "foo"
#   bash <(curl -fsSL .../server-dev.sh) --hostname random     # random wolf-themed hostname
#   bash <(curl -fsSL .../server-dev.sh) --ai                  # also install Claude Code + Codex CLIs
#
# (When piping via process substitution, flags go after the closing paren.)
set -e

REPO_URL="https://github.com/nathanialhenniges/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# Wolf-themed hostnames for --hostname random.
WOLF_HOSTNAMES=(fenrir lupus luna shadow ghost timber sirius akela balto \
  storm aspen grey nanuk yuki koda tundra vesper draco onyx rowan)

# Parse flags.
HOSTNAME_ARG=""
INSTALL_AI=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hostname)   HOSTNAME_ARG="${2:-random}"; shift; [[ $# -gt 0 ]] && shift ;;
    --hostname=*) HOSTNAME_ARG="${1#*=}"; shift ;;
    --ai)         INSTALL_AI=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Try: --hostname <name|random>, --ai, --help" >&2
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
  log "Setting hostname to '$name'..."
  sudo hostnamectl set-hostname "$name"
  # Keep /etc/hosts 127.0.1.1 in sync so `sudo` and name resolution stay happy.
  if grep -q '^127\.0\.1\.1' /etc/hosts; then
    sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$name/" /etc/hosts
  else
    printf '127.0.1.1\t%s\n' "$name" | sudo tee -a /etc/hosts >/dev/null
  fi
  substep "Hostname set to '$name'"
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

install_ai_clis() {
  # npm globals — need Node. install_fnm_node activates the default version, but
  # fall back to `fnm exec` so this works even if PATH activation didn't stick.
  local npm_cmd=""
  if command -v npm &>/dev/null; then
    npm_cmd="npm"
  elif command -v fnm &>/dev/null; then
    npm_cmd="fnm exec --using=default npm"
  fi
  if [[ -n "$npm_cmd" ]]; then
    log "Installing AI CLIs (Claude Code, Codex)..."
    $npm_cmd install -g @anthropic-ai/claude-code @openai/codex
    substep "claude-code + codex installed globally"
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

# ── Semi-lockdown hardening (always runs) ────────────────────────────────────
# Ports the BASE hardening from mrdemonwolf/server-setup (ssh, sysctl, firewall,
# unattended-upgrades). Assumes the sudo account + your SSH key already exist —
# this script only hardens, it does NOT create the user.

install_security_packages() {
  log "Installing security packages..."
  sudo apt install -y ufw fail2ban ca-certificates gnupg
}

harden_ssh() {
  log "Hardening sshd..."
  # Ubuntu's stock sshd_config already `Include`s /etc/ssh/sshd_config.d/*.conf,
  # so a drop-in is safer than rewriting the whole file.
  local dropin="/etc/ssh/sshd_config.d/99-hardening.conf"

  # Lockout guard: only kill password auth once THIS user has a key installed,
  # otherwise a keyless box with password auth off is unreachable.
  local password_line
  if [[ -s "$HOME/.ssh/authorized_keys" ]]; then
    password_line="PasswordAuthentication no"
  else
    password_line="# PasswordAuthentication left ON — no ~/.ssh/authorized_keys found for $USER"
    substep "WARNING: no SSH key for $USER — leaving password auth ENABLED."
    substep "         Add your key to ~/.ssh/authorized_keys, then re-run to lock it down."
  fi

  # Mirrors roles/ssh/templates/sshd_config.j2 (Port 22 kept as the default).
  sudo tee "$dropin" >/dev/null <<EOF
# Managed by server-dev.sh — mirrors mrdemonwolf/server-setup ssh role.
PermitRootLogin prohibit-password
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
  if sudo sshd -t; then
    sudo systemctl restart ssh
    substep "sshd hardened and restarted"
  else
    substep "ERROR: sshd -t failed — removing drop-in, sshd left unchanged"
    sudo rm -f "$dropin"
    return 1
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
  sudo sysctl --system >/dev/null
  substep "sysctl hardening applied"
}

harden_firewall() {
  log "Configuring UFW (SSH only)..."
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  # Allow SSH BEFORE enabling, or enabling drops the current session.
  sudo ufw allow 22/tcp comment 'SSH'
  sudo ufw --force enable
  substep "UFW enabled — inbound denied except SSH (dev ports via 'ssh -L')"
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
  harden_firewall
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
[[ -n "$INSTALL_AI" ]] && install_ai_clis
install_docker

# Semi-lockdown hardening
harden_server

set_default_shell

echo ""
echo "==> Done! Next steps:"
echo "    - Open a SECOND SSH session NOW to confirm key login still works"
echo "      before you disconnect this one (sshd was just restarted)."
echo "    - Reconnect your SSH session to start using zsh + fnm."
echo "    - Log out and back in for Docker group membership to apply."
echo "    - Run 'gh auth login' to authenticate the GitHub CLI."
echo "      To scope gh to a single org, use a fine-grained PAT:"
echo "      gh auth login --with-token < token.txt   (see README)"
echo "    - Reach dev app ports from your laptop with SSH forwarding, e.g.:"
echo "      ssh -L 3000:localhost:3000 $USER@<this-box>   (see README)"
