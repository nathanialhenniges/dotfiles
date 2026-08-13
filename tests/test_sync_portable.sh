#!/bin/bash
# Exercises portable_filter() and sync_file() from sync.sh.
#
# The bug they guard: installers append absolute paths to the shell configs —
# `export PATH="/Users/you/.local/bin:$PATH"` — and sync.sh committed them
# verbatim. That path does not exist on the Ubuntu boxes, so a capture taken on
# the Mac quietly degraded every Linux machine reading this repo.
set -u

SYNC="${1:-$HOME/Developer/nathanialhenniges/dotfiles/sync.sh}"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Pretend this is the machine being synced, so the filter has a home prefix to
# rewrite that is not the real one.
HOME="$TMP/home"
mkdir -p "$HOME"

# Pull in just the two functions so sourcing sync.sh cannot run the real sync.
eval "$(awk '/^portable_filter\(\) \{/,/^\}/' "$SYNC")"
eval "$(awk '/^sync_file\(\) \{/,/^\}/' "$SYNC")"

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

cat > "$HOME/.zshrc" <<EOF
export PATH="$HOME/.local/bin:\$PATH"
[[ -d "\$HOME/.lmstudio/bin" ]] && export PATH="\$PATH:\$HOME/.lmstudio/bin"
alias devdir="cd $HOME"
# unrelated line mentioning /Users/someoneelse/thing
EOF

sync_file "$HOME/.zshrc" "$TMP/out/.zshrc"

has() { grep -Fq "$1" "$TMP/out/.zshrc" && echo yes || echo no; }

check "absolute home rewritten"    yes "$(has 'export PATH="$HOME/.local/bin:$PATH"')"
check "trailing home rewritten"    yes "$(has 'alias devdir="cd $HOME"')"
check "no literal home left"       no  "$(has "$HOME/")"
check "already-portable untouched" yes "$(has '[[ -d "$HOME/.lmstudio/bin" ]]')"
check "other users left alone"     yes "$(has '/Users/someoneelse/thing')"
check "line count preserved"       4   "$(wc -l < "$TMP/out/.zshrc" | tr -d ' ')"

# strip_pattern still applies, and applies before the rewrite.
printf 'keep=1\ntelemetry.seed=abc123\nkeep=2\n' > "$HOME/.nuxtrc"
sync_file "$HOME/.nuxtrc" "$TMP/out/.nuxtrc" '^telemetry\.seed='
check "strip pattern honoured" 0 "$(grep -c telemetry "$TMP/out/.nuxtrc")"
check "strip keeps other lines" 2 "$(wc -l < "$TMP/out/.nuxtrc" | tr -d ' ')"

# ~/.scripts/* must stay runnable after the filter rewrites the file.
mkdir -p "$HOME/.scripts"
printf '#!/bin/bash\necho "$HOME"\n' > "$HOME/.scripts/thing"
chmod +x "$HOME/.scripts/thing"
sync_file "$HOME/.scripts/thing" "$TMP/out/.scripts/thing"
check "executable bit preserved" yes "$([ -x "$TMP/out/.scripts/thing" ] && echo yes || echo no)"

printf 'not executable\n' > "$HOME/plain"
sync_file "$HOME/plain" "$TMP/out/plain"
check "non-executable stays plain" no "$([ -x "$TMP/out/plain" ] && echo yes || echo no)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
