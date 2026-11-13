#!/bin/bash
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/server-dev.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
log() { :; }
substep() { :; }
unminimize() { :; }
dpkg-query() { echo installed; }
systemctl() { echo 'rpcbind.socket enabled'; }
sudo() {
  if [[ "$1" == env ]]; then
    local answer
    read -r answer
    [[ "$answer" == y ]] || return 9
    return "$consumer_result"
  fi
  printf '%s\n' "$*" >> "$tmp/cleanup"
}
eval "$(sed -n '/^restore_docs() {/,/^}/p' "$SCRIPT")"
consumer_result=0
restore_docs
grep -q 'apt-get install -y linux-oracle' "$tmp/cleanup"
grep -q 'disable --now rpcbind.socket rpcbind.service' "$tmp/cleanup"
echo 'PASS: successful unminimize tolerates yes SIGPIPE and disables rpcbind'
rm "$tmp/cleanup"
consumer_result=7
set +e
restore_docs
status=$?
set -e
[[ "$status" == 7 ]]
grep -q 'apt-get install -y linux-oracle' "$tmp/cleanup"
grep -q 'disable --now rpcbind.socket rpcbind.service' "$tmp/cleanup"
echo 'PASS: real unminimize failures are returned after rpcbind cleanup'
