#!/bin/bash
# Exercises brewfile_orphans() and prune_brewfile() from lib/bootstrap.sh.
#
# merge_brewfile only ever adds, so without a report the Brewfile rots: an app
# uninstalled a year ago stays queued for the next machine you build and nothing
# says so. These assertions cover the reporting, and the guard that matters most
# — a category whose query tool is missing must be skipped, not declared dead.
# Without it, a box with no `code` on PATH would call every VS Code extension an
# orphan and offer to delete all of them.
set -u

LIB="${1:-$HOME/Developer/nathanialhenniges/dotfiles/lib/bootstrap.sh}"

eval "$(awk '/^brewfile_orphans\(\) \{/,/^\}/' "$LIB")"
eval "$(awk '/^prune_brewfile\(\) \{/,/^\}/' "$LIB")"

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

# Fake toolchain: brew knows one formula and one cask, code knows one extension.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/brew" <<'EOF'
#!/bin/sh
case "$2" in
  --formula) printf 'exiftool\noh-my-posh\n' ;;
  --cask)    printf 'ghostty\n' ;;
esac
EOF
cat > "$TMP/bin/code" <<'EOF'
#!/bin/sh
printf 'esbenp.prettier-vscode\n'
EOF
chmod +x "$TMP/bin/brew" "$TMP/bin/code"

cat > "$TMP/Brewfile" <<'EOF'
tap "hashicorp/tap"
brew "exiftool"
brew "gemini-cli"
brew "jandedobbeleer/oh-my-posh/oh-my-posh"
cask "ghostty"
cask "raycast"
vscode "esbenp.prettier-vscode"
vscode "eamodio.gitlens"
EOF

got=$(PATH="$TMP/bin:/usr/bin:/bin" brewfile_orphans "$TMP/Brewfile")

has() { printf '%s\n' "$got" | grep -Fxq "$1" && echo yes || echo no; }

check "missing formula reported"      yes "$(has 'brew "gemini-cli"')"
check "missing cask reported"         yes "$(has 'cask "raycast"')"
check "missing vscode ext reported"   yes "$(has 'vscode "eamodio.gitlens"')"
check "installed formula not reported" no "$(has 'brew "exiftool"')"
check "installed cask not reported"    no "$(has 'cask "ghostty"')"
check "installed vscode not reported"  no "$(has 'vscode "esbenp.prettier-vscode"')"
check "tap-qualified formula matched"  no "$(has 'brew "jandedobbeleer/oh-my-posh/oh-my-posh"')"
check "taps never reported"            no "$(has 'tap "hashicorp/tap"')"
check "orphan count"                   3  "$(printf '%s\n' "$got" | grep -c .)"

# THE important one: with no `code` on PATH, VS Code entries must be skipped
# entirely rather than reported as dead.
rm -f "$TMP/bin/code"
got_nocode=$(PATH="$TMP/bin:/usr/bin:/bin" brewfile_orphans "$TMP/Brewfile")
check "vscode skipped when code absent" 0 \
  "$(printf '%s\n' "$got_nocode" | grep -c '^vscode ')"
check "other categories still reported" 2 \
  "$(printf '%s\n' "$got_nocode" | grep -c .)"

# Pruning removes exactly the orphans and nothing else.
cat > "$TMP/bin/code" <<'EOF'
#!/bin/sh
printf 'esbenp.prettier-vscode\n'
EOF
chmod +x "$TMP/bin/code"
PATH="$TMP/bin:/usr/bin:/bin" prune_brewfile "$TMP/Brewfile" "$TMP/pruned"
check "pruned line count"           5 "$(grep -c . "$TMP/pruned")"
check "kept installed entries"      1 "$(grep -cx 'brew \"exiftool\"' "$TMP/pruned")"
check "kept the tap"                1 "$(grep -cx 'tap \"hashicorp/tap\"' "$TMP/pruned")"
check "dropped the orphan"          0 "$(grep -cx 'cask \"raycast\"' "$TMP/pruned")"
check "prune leaves no orphans"     0 "$(PATH="$TMP/bin:/usr/bin:/bin" brewfile_orphans "$TMP/pruned" | grep -c .)"

# A clean Brewfile must survive pruning untouched.
PATH="$TMP/bin:/usr/bin:/bin" prune_brewfile "$TMP/pruned" "$TMP/pruned2"
check "prune is idempotent" 0 "$(diff "$TMP/pruned" "$TMP/pruned2" | wc -l | tr -d ' ')"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
