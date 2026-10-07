#!/usr/bin/env bash

set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_dir/travel-router.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

bash -n "$script"

help_output="$($script --help)"
[[ "$help_output" == *'root@10.69.42.1'* ]] || fail 'help omits the default router target'

dry_output="$($script --dry-run root@192.0.2.1)"
[[ "$dry_output" == *'root@192.0.2.1'* ]] || fail 'dry-run omits the selected target'
[[ "$dry_output" == *'Oh My Posh'* ]] || fail 'dry-run omits Oh My Posh'
[[ "$dry_output" == *'No network connection or files changed.'* ]] || fail 'dry-run safety message missing'

for bad_target in '-oProxyCommand=true' 'root@host extra'; do
  if "$script" --dry-run "$bad_target" >/dev/null 2>&1; then
    fail 'unsafe SSH target accepted'
  fi
  if TRAVEL_ROUTER_HOST="$bad_target" "$script" --dry-run >/dev/null 2>&1; then
    fail 'unsafe environment SSH target accepted'
  fi
done
if "$script" --dry-run root@192.0.2.1 unexpected >/dev/null 2>&1; then
  fail 'extra arguments accepted'
fi

grep -Fq "grep -q 'OpenWrt' /etc/openwrt_release" "$script" || fail 'OpenWrt preflight missing'
grep -Fq 'command -v apk' "$script" || fail 'apk preflight missing'
grep -Fq 'command -v zsh' "$script" || fail 'Zsh verification missing'
grep -Fq 'scp -O' "$script" || fail 'OpenWrt-compatible SCP mode missing'
grep -Fq 'https://ohmyposh.dev/install.sh' "$script" || fail 'Oh My Posh installer missing'
grep -Fq 'mrdemonwolf-server.omp.json' "$script" || fail 'MrDemonWolf server theme missing'
grep -Fq 'oh-my-posh init zsh --config /root/.config/ohmyposh/mrdemonwolf-server.omp.json' "$script" || fail 'Oh My Posh Zsh initialization missing'
grep -Fq "PROMPT='%F{cyan}%n@%m%f %F{blue}%~%f %# '" "$script" || fail 'recovery prompt missing'
grep -Fq "export SHELL=\"\$(command -v zsh)\"" "$script" || fail 'Zsh SHELL export missing'
grep -Fq '[ -t 0 ]' "$script" || fail 'interactive-shell guard missing'
grep -Fq 'exec zsh' "$script" || fail 'Zsh handoff missing'
! grep -Fq 'exec zsh -l' "$script" || fail 'Zsh handoff repeats the login banner'
grep -Fq '/etc/sysupgrade.conf' "$script" || fail 'sysupgrade preservation missing'
grep -Fq '/usr/local/bin/oh-my-posh' "$script" || fail 'Oh My Posh binary persistence missing'

printf 'travel-router tests passed\n'
