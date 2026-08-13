#!/bin/bash
# Exercises merge_brewfile() from lib/bootstrap.sh.
#
# The bug it guards: sync.sh used to run `brew bundle dump --force` straight
# over the Brewfile. The dump only knows what the Mac running sync happens to
# have, so every entry belonging to another machine — or uninstalled here for
# an afternoon — vanished from the repo and never came back on a rebuild.
set -u

LIB="${1:-$HOME/Developer/nathanialhenniges/dotfiles/lib/bootstrap.sh}"

# Pull in just merge_brewfile so sourcing the lib cannot run anything else.
eval "$(awk '/^merge_brewfile\(\) \{/,/^\}/' "$LIB")"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

check() { # name expected actual
  local name=$1 want=$2 got=$3
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-46s (%s)\n' "$name" "$want"
    pass=$((pass + 1))
  else
    printf '  FAIL  %-46s want=%s got=%s\n' "$name" "$want" "$got"
    fail=$((fail + 1))
  fi
}

cat > "$TMP/existing" <<'EOF'
tap "hashicorp/tap"
brew "exiftool"
brew "gemini-cli"
cask "raycast"
mas "uBlock Origin Lite", id: 6745342698
vscode "eamodio.gitlens"
EOF

# What this Mac reports: gemini-cli and raycast are gone, ripgrep is new, and
# the tap now carries Homebrew's trusted: option.
cat > "$TMP/dump" <<'EOF'
# Description comment that dump likes to emit
tap "hashicorp/tap", trusted: true
brew "exiftool"
brew "ripgrep"
cask "orbstack"
npm "wrangler"
EOF

merge_brewfile "$TMP/existing" "$TMP/dump" "$TMP/out"

has() { grep -Fxq "$1" "$TMP/out" && echo yes || echo no; }

check "uninstalled formula kept"      yes "$(has 'brew "gemini-cli"')"
check "uninstalled cask kept"         yes "$(has 'cask "raycast"')"
check "vscode entry kept"             yes "$(has 'vscode "eamodio.gitlens"')"
check "new formula added"             yes "$(has 'brew "ripgrep"')"
check "new cask added"                yes "$(has 'cask "orbstack"')"
check "new npm entry added"           yes "$(has 'npm "wrangler"')"
check "mas entry kept"                yes "$(has 'mas "uBlock Origin Lite", id: 6745342698')"
check "recorded tap form wins"        yes "$(has 'tap "hashicorp/tap"')"
check "trusted: variant not dupe"     no  "$(has 'tap "hashicorp/tap", trusted: true')"
check "dump comment not copied"       0   "$(grep -c '^#' "$TMP/out")"
check "no entry duplicated"           0   "$(sort "$TMP/out" | uniq -d | wc -l | tr -d ' ')"
check "nothing removed"               0   "$(comm -23 <(sort "$TMP/existing") <(sort "$TMP/out") | wc -l | tr -d ' ')"

# Grouping: every tap before every brew before every cask.
order=$(sed -E 's/^([a-z]+) .*/\1/' "$TMP/out" | uniq | tr '\n' ' ')
check "grouped by kind" "tap brew cask mas npm vscode " "$order"

# Second run over its own output must be a no-op, or sync churns every diff.
merge_brewfile "$TMP/out" "$TMP/dump" "$TMP/out2"
check "idempotent" 0 "$(diff "$TMP/out" "$TMP/out2" | wc -l | tr -d ' ')"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
