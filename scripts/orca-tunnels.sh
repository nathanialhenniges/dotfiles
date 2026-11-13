#!/bin/bash
# Managed by dotfiles orca-tunnels.sh
# Mac-side SSH forwards that let Orca reach private remote Orca servers.
# Names below are SSH aliases; real addresses stay in ~/.ssh/config.
set -euo pipefail

# name  local-port  ssh-alias  mode (auto = start at login and keep alive)
TUNNELS=(
  'cloud 16768 mrdemonwolf-dev auto'
  'mini 16769 mdws-mini-dev manual'
)
REMOTE=127.0.0.1:6769
PREFIX=com.nathanialhenniges.orca-tunnel
MARKER='# Managed by dotfiles orca-tunnels.sh'

die() { echo "error: $*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: orca-tunnels <command> [cloud|mini|all]

  install [--dry-run]   Write LaunchAgents and the orca-tunnels command
  uninstall             Remove them (stops every tunnel)
  status                Show each tunnel (default command)
  start | stop | restart [name]

cloud starts at login and restarts itself. mini starts only when asked,
because its Cloudflare route may need a browser sign-in.
EOF
}

[[ $(uname -s) == Darwin ]] || die 'orca-tunnels runs on macOS only'
[[ ${HOME:-} == /* && -d "${HOME:-}" ]] || die 'HOME must be an existing absolute directory'
AGENTS="$HOME/Library/LaunchAgents"
LOGS="$HOME/Library/Logs/orca-tunnels"
BIN="$HOME/.local/bin/orca-tunnels"
DOMAIN="gui/$(id -u)"

# Prints "name port alias mode" for one tunnel or all of them.
select_tunnels() {
  local want=${1:-all} found=false row name
  for row in "${TUNNELS[@]}"; do
    read -r name _ <<<"$row"
    if [[ "$want" == all || "$want" == "$name" ]]; then echo "$row"; found=true; fi
  done
  [[ "$found" == true ]] || die "unknown tunnel: $want (use cloud, mini or all)"
}

plist() {
  local name=$1 port=$2 alias=$3 mode=$4 keep=false
  [[ "$alias" =~ ^[A-Za-z0-9._-]+$ ]] || die "unsafe SSH alias: $alias"
  [[ "$mode" == auto ]] && keep=true
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$PREFIX.$name</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/ssh</string>
    <string>-N</string>
    <string>-o</string><string>ExitOnForwardFailure=yes</string>
    <string>-o</string><string>BatchMode=yes</string>
    <string>-o</string><string>ServerAliveInterval=15</string>
    <string>-o</string><string>ServerAliveCountMax=3</string>
    <string>-L</string><string>127.0.0.1:$port:$REMOTE</string>
    <string>$alias</string>
  </array>
  <key>RunAtLoad</key><$keep/>
  <key>KeepAlive</key><$keep/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>ProcessType</key><string>Background</string>
  <key>StandardOutPath</key><string>$LOGS/$name.log</string>
  <key>StandardErrorPath</key><string>$LOGS/$name.log</string>
</dict>
</plist>
EOF
}

loaded() { launchctl print "$DOMAIN/$PREFIX.$1" >/dev/null 2>&1; }
listening() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

cmd_install() {
  local dry=${1:-} row name port alias mode file
  if [[ "$dry" == --dry-run ]]; then
    while read -r name port alias mode; do
      echo "Would write $AGENTS/$PREFIX.$name.plist: 127.0.0.1:$port -> $alias $REMOTE ($mode)"
    done < <(select_tunnels all)
    echo "Would install $BIN. No SSH config, firewall or server changes."
    return
  fi
  for path in "$AGENTS" "$LOGS" "$HOME/.local/bin"; do
    [[ ! -L "$path" ]] || die "refusing symbolic-link directory: $path"
  done
  mkdir -p "$AGENTS" "$LOGS" "$HOME/.local/bin"
  chmod 700 "$LOGS"
  if [[ -e "$BIN" || -L "$BIN" ]]; then
    [[ ! -L "$BIN" ]] && grep -qxF "$MARKER" "$BIN" || die "refusing to replace unmanaged $BIN"
  fi
  install -m 755 "${BASH_SOURCE[0]}" "$BIN"
  while read -r name port alias mode; do
    file="$AGENTS/$PREFIX.$name.plist"
    [[ ! -L "$file" ]] || die "refusing symbolic-link LaunchAgent: $file"
    plist "$name" "$port" "$alias" "$mode" > "$file.tmp"
    plutil -lint -s "$file.tmp" || die "invalid plist for $name"
    mv "$file.tmp" "$file"
    loaded "$name" && launchctl bootout "$DOMAIN/$PREFIX.$name" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$file"
    echo "Installed $name ($mode): localhost:$port -> $alias"
  done < <(select_tunnels all)
}

cmd_uninstall() {
  local name
  while read -r name _; do
    loaded "$name" && launchctl bootout "$DOMAIN/$PREFIX.$name" 2>/dev/null || true
    rm -f "$AGENTS/$PREFIX.$name.plist"
  done < <(select_tunnels all)
  if [[ -f "$BIN" && ! -L "$BIN" ]] && grep -qxF "$MARKER" "$BIN"; then rm -f "$BIN"; fi
  echo 'Removed Orca tunnels.'
}

cmd_status() {
  local name port alias mode state
  printf '%-6s %-6s %-16s %-7s %s\n' TUNNEL PORT ALIAS MODE STATE
  while read -r name port alias mode; do
    if listening "$port"; then state=up
    elif ! [[ -f "$AGENTS/$PREFIX.$name.plist" ]]; then state='not installed'
    elif loaded "$name" && [[ "$mode" == auto ]]; then state="down, retrying (log: $LOGS/$name.log)"
    else state="down (orca-tunnels start $name)"
    fi
    printf '%-6s %-6s %-16s %-7s %s\n' "$name" "$port" "$alias" "$mode" "$state"
  done < <(select_tunnels "${1:-all}")
}

cmd_start() {
  local name
  while read -r name _; do
    [[ -f "$AGENTS/$PREFIX.$name.plist" ]] || die "not installed; run: orca-tunnels install"
    loaded "$name" || launchctl bootstrap "$DOMAIN" "$AGENTS/$PREFIX.$name.plist"
    launchctl kickstart "$DOMAIN/$PREFIX.$name"
  done < <(select_tunnels "${1:-all}")
}

# Unloads until the next login (auto) or the next start.
cmd_stop() {
  local name
  while read -r name _; do
    loaded "$name" && launchctl bootout "$DOMAIN/$PREFIX.$name" 2>/dev/null || true
  done < <(select_tunnels "${1:-all}")
}

cmd_restart() {
  local name
  while read -r name _; do
    [[ -f "$AGENTS/$PREFIX.$name.plist" ]] || die "not installed; run: orca-tunnels install"
    loaded "$name" || launchctl bootstrap "$DOMAIN" "$AGENTS/$PREFIX.$name.plist"
    launchctl kickstart -k "$DOMAIN/$PREFIX.$name"
  done < <(select_tunnels "${1:-all}")
}

command=${1:-status}
[[ $# -le 2 ]] || die 'too many arguments'
# Validate here: a die inside the process substitutions below cannot stop the script.
if [[ "$command" =~ ^(status|start|stop|restart)$ ]]; then
  select_tunnels "${2:-all}" >/dev/null
fi
case "$command" in
  install) cmd_install "${2:-}" ;;
  uninstall) cmd_uninstall ;;
  status) cmd_status "${2:-all}" ;;
  start) cmd_start "${2:-all}" ;;
  stop) cmd_stop "${2:-all}" ;;
  restart) cmd_restart "${2:-all}" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 1 ;;
esac
