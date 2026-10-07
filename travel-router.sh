#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./travel-router.sh [--dry-run] [user@host]

Install Zsh and the MrDemonWolf Oh My Posh setup on an OpenWrt travel router.
The default target is root@10.69.42.1.
EOF
}

dry_run=0
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --dry-run)
    dry_run=1
    shift
    ;;
  -*)
    usage >&2
    exit 2
    ;;
esac

if (( $# > 1 )); then
  usage >&2
  exit 2
fi
target="${1:-${TRAVEL_ROUTER_HOST:-root@10.69.42.1}}"
if [[ "$target" == -* || "$target" == *[[:space:]]* ]]; then
  printf 'Invalid SSH target: use a host or user@host without whitespace or leading options.\n' >&2
  exit 2
fi
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
theme="$script_dir/config/server/.config/ohmyposh/mrdemonwolf-server.omp.json"

if (( dry_run )); then
  printf 'Would configure %s with Zsh, Oh My Posh, the MrDemonWolf server theme, and router aliases.\n' "$target"
  printf 'No network connection or files changed.\n'
  exit 0
fi

command -v ssh >/dev/null 2>&1 || {
  printf 'ssh is required.\n' >&2
  exit 1
}
command -v scp >/dev/null 2>&1 || {
  printf 'scp is required.\n' >&2
  exit 1
}
[ -r "$theme" ] || {
  printf 'Theme not found: %s\n' "$theme" >&2
  exit 1
}

printf 'Configuring %s...\n' "$target"
scp -O "$theme" "$target:/tmp/mrdemonwolf-server.omp.json"

ssh "$target" 'sh -s' <<'REMOTE'
set -eu
trap 'rm -f /tmp/mrdemonwolf-server.omp.json' EXIT

grep -q 'OpenWrt' /etc/openwrt_release 2>/dev/null || {
  echo 'This installer only supports OpenWrt.' >&2
  exit 1
}

command -v apk >/dev/null 2>&1 || {
  echo 'OpenWrt apk package manager not found.' >&2
  exit 1
}

apk update
apk add bash curl unzip coreutils-realpath zsh
command -v zsh >/dev/null 2>&1 || {
  echo 'zsh installation failed.' >&2
  exit 1
}

backup_once() {
  [ ! -e "$1" ] || [ -e "$1.backup" ] || cp -p "$1" "$1.backup"
}

backup_once /root/.profile
backup_once /root/.zshrc
touch /root/.profile

mkdir -p /usr/local/bin /root/.config/ohmyposh
curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d /usr/local/bin
command -v /usr/local/bin/oh-my-posh >/dev/null 2>&1 || {
  echo 'Oh My Posh installation failed.' >&2
  exit 1
}
backup_once /root/.config/ohmyposh/mrdemonwolf-server.omp.json
install -m 0644 /tmp/mrdemonwolf-server.omp.json \
  /root/.config/ohmyposh/mrdemonwolf-server.omp.json

sed -i '/^# BEGIN dotfiles travel-router$/,/^# END dotfiles travel-router$/d' /root/.profile
cat >> /root/.profile <<'PROFILE'
# BEGIN dotfiles travel-router
if [ -t 0 ] && [ -z "${ZSH_VERSION:-}" ] && command -v zsh >/dev/null 2>&1; then
  exec zsh
fi
# END dotfiles travel-router
PROFILE

cat > /root/.zshrc <<'ZSHRC'
[[ "$TERM" == "xterm-ghostty" ]] && export TERM="xterm-256color"
export PATH="/usr/local/bin:$PATH"
export SHELL="$(command -v zsh)"

export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000

setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt INTERACTIVE_COMMENTS
unsetopt BEEP

autoload -Uz compinit
compinit -i -d "$HOME/.zcompdump"
bindkey -e

if (( $+commands[oh-my-posh] )) && [[ -r /root/.config/ohmyposh/mrdemonwolf-server.omp.json ]]; then
  eval "$(oh-my-posh init zsh --config /root/.config/ohmyposh/mrdemonwolf-server.omp.json)"
else
  autoload -Uz colors
  colors
  PROMPT='%F{cyan}%n@%m%f %F{blue}%~%f %# '
fi

alias ll='ls -lah'
alias la='ls -A'
alias ..='cd ..'
alias ...='cd ../..'
alias wanip='wget -qO- https://api.ipify.org; echo'

(( $+commands[netmode] )) && {
  alias router-status='netmode status'
  alias router-ethernet='netmode eth'
  alias router-usb='netmode usb'
}

(( $+commands[ttlmode] )) && {
  alias ttl-status='ttlmode status'
  alias ttl-on='ttlmode on'
  alias ttl-off='ttlmode off'
}
ZSHRC

chmod 0644 /root/.profile /root/.zshrc

for managed_path in \
  /root/.profile \
  /root/.zshrc \
  /root/.config/ohmyposh/mrdemonwolf-server.omp.json \
  /usr/local/bin/oh-my-posh; do
  grep -qxF "$managed_path" /etc/sysupgrade.conf 2>/dev/null || \
    printf '%s\n' "$managed_path" >> /etc/sysupgrade.conf
done

TERM=xterm-256color zsh -fc 'source /root/.zshrc; [[ "$HISTSIZE" -eq 10000 ]] && command -v oh-my-posh >/dev/null'
echo 'Travel-router Zsh and Oh My Posh setup passed its self-check.'
REMOTE

printf 'Done. Reconnect to %s; interactive SSH sessions will enter Zsh automatically.\n' "$target"
