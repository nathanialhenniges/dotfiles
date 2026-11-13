#!/bin/bash
# Exercise the real parser and tool dispatch without installing anything.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/server-dev.sh"
parser=$(sed -n '/^# Parse flags\./,/^echo "==> Dev server bootstrap starting/p' "$SCRIPT" | sed '$d')
dispatch=$(sed -n '/^# Dev tooling$/,/^# Cloud images/p' "$SCRIPT" | sed '1d;$d')

check() {
  local expected="$1" actual fn
  shift
  actual=$(
    for fn in install_dev_packages install_extra_clis install_bun \
      install_fnm_node install_pnpm install_ai_clis install_claude_swap agent_setup install_chrome install_playwright install_php \
      install_docker install_orca_server restore_docs; do
      eval "$fn() { echo $fn; }"
    done
    set -- "$@"
    eval "$parser"
    eval "$dispatch"
  )
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: flags %s\nExpected:\n%s\nActual:\n%s\n' "$*" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "${*:-minimal default}"
}

base=$'install_dev_packages\ninstall_bun\ninstall_fnm_node'
check "$base"$'\ninstall_docker'
check "$base"$'\ninstall_ai_clis\ninstall_claude_swap\ninstall_docker' --ai
check "$base"$'\ninstall_docker\ninstall_orca_server' --orca-server
check $'install_dev_packages\ninstall_extra_clis\ninstall_bun\ninstall_fnm_node\ninstall_docker' --extras
check "$base"$'\ninstall_docker\nrestore_docs' --docs
check "$base"$'\nagent_setup\ninstall_claude_swap\ninstall_chrome\ninstall_docker' --agent-setup --chrome
check $'install_dev_packages\ninstall_extra_clis\ninstall_bun\ninstall_fnm_node\nagent_setup\ninstall_claude_swap\ninstall_playwright\ninstall_php\ninstall_chrome\ninstall_docker' --agent-setup --playwright --php --extras --chrome
check "$base"$'\ninstall_playwright\ninstall_php\ninstall_docker' --playwright --php
check $'install_dev_packages\ninstall_extra_clis\ninstall_bun\ninstall_fnm_node\ninstall_pnpm\ninstall_ai_clis\nagent_setup\ninstall_claude_swap\ninstall_playwright\ninstall_php\ninstall_chrome\ninstall_docker\nrestore_docs' \
  --extras --docs --pnpm --ai --agent-setup --playwright --php --chrome
for flag in --extras --docs --playwright --php --orca-server; do
  bash "$SCRIPT" --help | grep -q -- "$flag"
done
printf 'PASS: optional packages documented in help\n'

if bash "$SCRIPT" --go >/dev/null 2>&1; then
  echo 'FAIL: removed --go option accepted' >&2
  exit 1
fi
printf 'PASS: removed --go option rejected\n'

# Verify the real installers request the intended tools without executing them.
log() { :; }
substep() { :; }
sudo() { printf '%s\n' "$*"; }
npx() { printf '%s\n' "$*"; }
eval "$(sed -n '/^install_playwright() {/,/^}/p' "$SCRIPT")"
eval "$(sed -n '/^install_php() {/,/^}/p' "$SCRIPT")"
eval "$(sed -n '/^install_dev_packages() {/,/^}/p' "$SCRIPT")"
[[ "$(install_playwright)" == $'apt-get install -y --no-install-recommends xvfb xauth\n--yes playwright@1.64.1 install --with-deps chromium webkit' ]]
printf 'PASS: Playwright installs Chromium/WebKit, OS libraries, and a virtual display\n'
[[ "$(install_php)" == 'apt-get install -y --no-install-recommends php-cli php-curl php-mbstring php-xml php-zip composer' ]]
printf 'PASS: PHP uses CLI and required extensions without recommended packages\n'
# gh is already installed in this fixture; avoid exercising network repo setup.
gh() { :; }
packages=$(install_dev_packages)
[[ "$packages" == *'apt-get install -y --no-install-recommends build-essential python3 python3-venv ripgrep shellcheck zip jq direnv btop'* ]]
[[ "$packages" != *golang* ]]
printf 'PASS: common script/search/test tools are explicit; Go stays excluded\n'
eval "$(sed -n '/^install_pnpm() {/,/^}/p' "$SCRIPT")"
npm_global_cmd() { echo npm; }
npm() { printf '%s\n' "$*"; }
[[ "$(install_pnpm)" == "install -g --prefix $HOME/.local pnpm" ]]
printf 'PASS: pnpm remains available across fnm Node versions\n'

# Both supported CPU architectures must use native Google Chrome, without Snap.
chrome_log=$(mktemp)
trap 'rm -f "$chrome_log"' EXIT
for chrome_arch in amd64 arm64; do
  : > "$chrome_log"
  (
    eval "$(sed -n '/^install_chrome() {/,/^}/p' "$SCRIPT")"
    command() {
      if [[ "${1:-}" == -v && "${2:-}" == google-chrome-stable ]]; then
        return 1
      fi
      builtin command "$@"
    }
    dpkg() { echo "$chrome_arch"; }
    curl() { echo 'mock signing key'; }
    google-chrome-stable() { echo 'mock browser version'; }
    sudo() {
      printf '%s\n' "$*" >> "$chrome_log"
      case "$1" in tee|gpg) cat >> "$chrome_log" ;; esac
    }
    install_chrome
  )
  grep -Fq "deb [arch=$chrome_arch signed-by=/etc/apt/keyrings/google-chrome.gpg]" "$chrome_log"
  grep -Fq 'gpg --batch --yes --dearmor' "$chrome_log"
  grep -Fq 'apt-get install -y --no-install-recommends google-chrome-stable fonts-liberation' "$chrome_log"
  if grep -q 'snap\|chromium-browser' "$chrome_log"; then
    echo 'FAIL: native Chrome install used Snap/Chromium' >&2
    exit 1
  fi
  printf 'PASS: native Google Chrome on %s, with repeatable key import\n' "$chrome_arch"
done
