#!/bin/bash
# Exercises copy_configs() from lib/bootstrap.sh, specifically that a SECOND
# run does not overwrite the .backup written by the first.
#
# The bug: the `cp "$target" "$target.backup"` was unconditional, so run 2
# copied the dotfiles-managed file over the pristine pre-dotfiles original.
# The backup silently became a copy of the thing it was supposed to protect
# you from, and only on the run where you were most likely to need it.
set -u

LIB="${1:-$HOME/Developer/nathanialhenniges/dotfiles/lib/bootstrap.sh}"

# Stub the logging helpers the function calls, then pull in just copy_configs
# so sourcing the lib cannot run anything else.
log()     { :; }
substep() { :; }
eval "$(awk '/^copy_configs\(\) \{/,/^\}/' "$LIB")"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

check() { # name expected actual
  local name=$1 want=$2 got=$3
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-46s (%s)\n' "$name" "$want"
    pass=$((pass+1))
  else
    printf '  FAIL  %-46s want=%q got=%q\n' "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# Fake dotfiles source tree + a fake $HOME holding a pre-existing user file.
SRC="$TMP/src"; mkdir -p "$SRC"
printf 'MANAGED v1\n' > "$SRC/.aliases"

export HOME="$TMP/home"; mkdir -p "$HOME"
printf 'ORIGINAL USER FILE\n' > "$HOME/.aliases"

# ── run 1: no .backup exists yet, so one gets written ────────────────────────
copy_configs "$SRC" >/dev/null 2>&1
check "run 1 installs the managed file"  "MANAGED v1"          "$(cat "$HOME/.aliases")"
check "run 1 backs up the original"      "ORIGINAL USER FILE"  "$(cat "$HOME/.aliases.backup")"

# ── run 2: the source changed; .backup must NOT be touched ───────────────────
printf 'MANAGED v2\n' > "$SRC/.aliases"
copy_configs "$SRC" >/dev/null 2>&1
check "run 2 installs the new managed file" "MANAGED v2"         "$(cat "$HOME/.aliases")"
check "run 2 PRESERVES the original backup" "ORIGINAL USER FILE" "$(cat "$HOME/.aliases.backup")"

# ── run 3: same again, to catch an off-by-one "only guards once" fix ─────────
printf 'MANAGED v3\n' > "$SRC/.aliases"
copy_configs "$SRC" >/dev/null 2>&1
check "run 3 still preserves the original"  "ORIGINAL USER FILE" "$(cat "$HOME/.aliases.backup")"

# ── a file with no pre-existing target gets no spurious backup ───────────────
printf 'NEW FILE\n' > "$SRC/.newrc"
copy_configs "$SRC" >/dev/null 2>&1
check "no backup for a file that did not exist" "absent" \
  "$([[ -e "$HOME/.newrc.backup" ]] && echo present || echo absent)"

echo
echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
