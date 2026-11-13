#!/bin/bash
# Private remote runtime; clients reach it through their own SSH port forward.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
dry_run=false
pairing_link=false
case "${1:-}" in
  --dry-run) dry_run=true; shift ;;
  --pairing-link) pairing_link=true; shift ;;
  -h|--help) echo 'Usage: setup-orca-server.sh [--dry-run | --pairing-link]'; exit 0 ;;
esac
[[ $# == 0 ]] || die "unknown option: $1"
[[ $(id -u) != 0 ]] || die 'run as the normal server user, not root'
[[ ${HOME:-} == /* && ${HOME:-} != / && -d "${HOME:-}" ]] || die 'HOME must be an existing absolute directory'
if [[ "$pairing_link" == true ]]; then
  python3 - "$HOME/.local/share/orca-server/serve-private.log" <<'PY'
from pathlib import Path
import re, sys
path = Path(sys.argv[1])
if path.is_symlink() or not path.is_file():
    raise SystemExit('No private startup output; run setup first.')
links = re.findall(r'orca://pair\?[^\s"<>]+', path.read_text())
if not links:
    raise SystemExit('No access link yet; check the service startup or rerun setup.')
print(links[-1])
PY
  exit
fi
os=$(uname -s)
case "$os" in
  Linux) client_port=16768 ;;
  Darwin) client_port=16769 ;;
  *) die 'only Linux and macOS are supported' ;;
esac
if [[ "$dry_run" == true ]]; then
  echo "Would install/reuse Orca and its per-user service on $os."
  echo "Would bind 127.0.0.1:6769, refuse public clients, advertise ws://127.0.0.1:$client_port."
  [[ "$os" != Linux ]] || echo 'Would enable Linux user lingering.'
  echo 'No firewall or DNS changes.'
  echo 'Dry run: no service or access link is created.'
  exit 0
fi

for path in "$HOME/.local" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/share/orca-server"; do
  [[ ! -L "$path" ]] || die "refusing symbolic-link directory: $path"
  [[ ! -e "$path" || -d "$path" ]] || die "not a directory: $path"
done
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/orca-server"
root="$HOME/.local/share/orca-server"
chmod 700 "$root"
launcher="$HOME/.local/bin/orca-server"
[[ ! -L "$launcher" ]] || die "refusing symbolic-link launcher: $launcher"
if [[ -e "$launcher" ]] && ! grep -q '^# Managed by dotfiles setup-orca-server.sh$' "$launcher"; then
  die "refusing to replace an unmanaged launcher: $launcher"
fi

if [[ "$os" == Linux ]]; then
  # A pinned server-only release avoids Electron/desktop dependencies.
  version=1.4.257
  case "$(uname -m)" in
    aarch64|arm64) arch=arm64; checksum=b847013eea2e8f023f217f5ad3f459166a2cebecdbc3ef8f1b6b8ebd5e821343 ;;
    x86_64) arch=x64; checksum=72f42c1f5e66d828375d70a54fda5a5f910b90471948d93eedbc3a9ed19bc840 ;;
    *) die 'Orca server supports Linux arm64 and x64 only' ;;
  esac
  release="$root/releases/$version"
  [[ ! -L "$root/releases" && ! -L "$release" ]] || die 'refusing a symbolic-link release directory'
  if [[ ! -e "$release" ]]; then
    temporary=$(mktemp -d)
    trap 'rm -rf -- "$temporary"' EXIT
    archive="$temporary/orca-server.tar.gz"
    curl --fail --location --retry 2 --output "$archive" \
      "https://github.com/stablyai/orca/releases/download/v$version/orca-server-linux-$arch.tar.gz"
    printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status -
    mkdir -p "$temporary/unpacked" "$root/releases"
    tar -xzf "$archive" -C "$temporary/unpacked" --strip-components=1 --no-same-owner
    [[ -x "$temporary/unpacked/bin/orca-ide" ]] || die 'release is missing its CLI'
    printf '%s\n' "$checksum" > "$temporary/unpacked/archive.sha256"
    mv "$temporary/unpacked" "$release"
  fi
  [[ -f "$release/archive.sha256" && "$(cat "$release/archive.sha256")" == "$checksum" ]] || die 'unrecognized existing release; preserve it and inspect before retrying'
  current="$root/current"
  if [[ -e "$current" || -L "$current" ]]; then
    [[ -L "$current" && "$(readlink "$current")" == "$root/releases/"* ]] || die 'refusing an unmanaged current path'
  fi
  cli="$HOME/.local/bin/orca-ide"
  if [[ -e "$cli" || -L "$cli" ]]; then
    [[ -L "$cli" && "$(readlink "$cli")" == "$current/bin/orca-ide" ]] || die 'an existing orca-ide command must be managed separately'
  fi
  ln -sfn "$release" "$current"
  ln -sfn "$current/bin/orca-ide" "$cli"
  if [[ "$(loginctl show-user "$(id -un)" -p Linger --value)" != yes ]]; then
    sudo loginctl enable-linger "$(id -un)"
  fi
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
else
  cli='/Applications/Orca.app/Contents/Resources/bin/orca'
  if [[ ! -x "$cli" ]]; then
    command -v brew >/dev/null || die 'install Homebrew first; this targeted setup does not bootstrap it'
    brew tap stablyai/orca
    HOMEBREW_NO_INSTALL_CLEANUP=1 brew install --cask stablyai/orca/orca
  fi
  [[ -x "$cli" ]] || die 'the Stably Orca CLI is missing from /Applications/Orca.app'
fi

# Orca's native service manager owns launchd/systemd, supervision and private logs.
{
  printf '#!/bin/bash\n# Managed by dotfiles setup-orca-server.sh\nset -e\n'
  cat <<'LAUNCHER'
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.local/share/fnm:/opt/homebrew/bin:/usr/local/bin:$PATH"
unset ORCA_PAIRING_CODE ORCA_ENVIRONMENT
if command -v fnm >/dev/null; then
  eval "$(fnm env --shell bash)"
  fnm use default >/dev/null
fi
export ORCA_SERVE_RUNTIME=orcad
if command -v google-chrome-stable >/dev/null; then
  export ORCA_BROWSER_EXECUTABLE="$(command -v google-chrome-stable)"
fi
if [[ "${1:-}" == serve && "${2:-}" != service ]]; then
  # shortcut: Orca 1.4.257 pair widens loopback; let systemd/launchd supervise plain serve until fixed.
  args=()
  for argument in "$@"; do
    case "$argument" in --no-pairing|--supervise) ;; *) args+=("$argument") ;; esac
  done
  umask 077
  private_log="$HOME/.local/share/orca-server/serve-private.log"
  [[ ! -L "$private_log" ]] || exit 1
  touch "$private_log"
  chmod 600 "$private_log"
LAUNCHER
  # shellcheck disable=SC2016
  printf '  exec %q "${args[@]}" --json >> "$private_log" 2>&1\nfi\n' "$cli"
  printf 'exec %q "$@"\n' "$cli"
} > "$launcher"
chmod 700 "$launcher"
"$launcher" serve service install --command "$launcher" --port 6769 \
  --bind 127.0.0.1 --refuse-public --pairing-address "ws://127.0.0.1:$client_port" --json
echo "Orca service configured. On your client: ssh -N -L 127.0.0.1:$client_port:127.0.0.1:6769 <ssh-alias>"
echo "Startup pairing output stays private: $root/serve-private.log"
echo 'Print the access link only when needed: bash ~/dotfiles/scripts/setup-orca-server.sh --pairing-link'
