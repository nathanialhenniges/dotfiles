#!/bin/bash
# Asserts the mapping tables in lib/bootstrap.sh still match the real tables
# inside install.sh (macOS) and linux-desktop.sh (Linux).
#
# sync.sh captures whatever those tables list, and the installers apply it. If
# the copies drift, sync silently stops capturing a file the installer still
# writes — so the repo keeps shipping a stale version of it forever, and the
# only symptom is that your change "didn't take" on the next machine.
set -u

REPO="${1:-$HOME/Developer/nathanialhenniges/dotfiles}"
LIB="$REPO/lib/bootstrap.sh"

# Pull in just the table functions so sourcing the lib cannot run anything else.
eval "$(awk '/^macos_mappings\(\) \{/,/^\}/' "$LIB")"
eval "$(awk '/^linux_mappings\(\) \{/,/^\}/' "$LIB")"

pass=0; fail=0

check() { # name expected actual
  local name=$1 want=$2 got=$3
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s\n' "$name"
    printf '        only in one side:\n'
    diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/          /'
    fail=$((fail + 1))
  fi
}

# install.sh lists "source:dest:mode" relative to config/. Drop the mode and
# re-add the config/ prefix to get the same shape the lib publishes.
installer_macos=$(
  awk '/local -a mappings=\(/,/^  \)/' "$REPO/install.sh" |
    grep -oE '"[^"]+"' | tr -d '"' |
    awk -F: 'NF>=3 {printf "config/%s:%s\n", $1, $2}' | sort
)
check "macOS table matches install.sh" "$installer_macos" "$(macos_mappings | sort)"

# linux-desktop.sh lists "source:dest" already relative to the repo root.
installer_linux=$(
  awk '/^mappings=\(/,/^\)/' "$REPO/linux-desktop.sh" |
    grep -oE '"[^"]+"' | tr -d '"' | sort
)
check "Linux table matches linux-desktop.sh" "$installer_linux" "$(linux_mappings | sort)"

# Every repo-side path in both tables must actually exist, or sync writes a file
# the installer will then refuse to apply ("missing or unsafe managed source").
orphans=$(
  { macos_mappings; linux_mappings; } | cut -d: -f1 | sort -u |
    while read -r path; do [ -f "$REPO/$path" ] || echo "$path"; done
)
check "every repo path exists" "" "$orphans"

# Identity files must never be captured into a public repo.
leaked=$({ macos_mappings; linux_mappings; } | grep -E '\.gitconfig|\.npmrc' || true)
check "no .gitconfig or .npmrc in tables" "" "$leaked"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
