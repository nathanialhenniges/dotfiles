#!/bin/bash
# Exercises portable_filter() and sync_file() from sync.sh.
#
# The bug they guard: installers append absolute paths to the shell configs —
# `export PATH="/Users/you/.local/bin:$PATH"` — and sync.sh committed them
# verbatim. That path does not exist on the Ubuntu boxes, so a capture taken on
# the Mac quietly degraded every Linux machine reading this repo.
set -u

SYNC="${1:-$HOME/Developer/nathanialhenniges/dotfiles/sync.sh}"
LIB="$(dirname "$SYNC")/lib/bootstrap.sh"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Pretend this is the machine being synced, so the filter has a home prefix to
# rewrite that is not the real one.
HOME="$TMP/home"
mkdir -p "$HOME"

# Pull in just the two functions so sourcing sync.sh cannot run the real sync.
eval "$(awk '/^portable_filter\(\) \{/,/^\}/' "$SYNC")"
eval "$(awk '/^filter_pattern\(\) \{/,/^\}/' "$SYNC")"
eval "$(awk '/^sync_file\(\) \{/,/^\}/' "$SYNC")"
eval "$(awk '/^strip_local\(\) \{/,/^\}/' "$SYNC")"
eval "$(awk '/^marker_missing\(\) \{/,/^\}/' "$SYNC")"
eval "$(awk '/^LOCAL_MARKER=/' "$LIB")"
eval "$(awk '/^read_local_block\(\) \{/,/^\}/' "$LIB")"
eval "$(awk '/^copy_preserving_local\(\) \{/,/^\}/' "$LIB")"
eval "$(awk '/^resolve_link\(\)/,/^}/' "$SYNC")"
eval "$(awk '/^sync_tree\(\) \{/,/^\}/' "$SYNC")"

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

cat > "$HOME/.zshrc" <<EOF
managed=1
$LOCAL_MARKER
export PATH="/Users/nathanialhenniges/private/bin:\$PATH"
EOF
sync_file "$HOME/.zshrc" "$TMP/out/.zshrc"
check "local block excluded" 0 "$(grep -c 'private/bin' "$TMP/out/.zshrc" || true)"
check "local marker retained" 1 "$(grep -cF "$LOCAL_MARKER" "$TMP/out/.zshrc")"
printf '%s\n' "$LOCAL_MARKER" > "$TMP/repo-marked"
printf 'unmarked home\n' > "$TMP/home-unmarked"
check "marked repo refuses unmarked home" yes "$(marker_missing "$TMP/repo-marked" "$TMP/home-unmarked" && echo yes || echo no)"
printf '%s\n' "$LOCAL_MARKER" > "$TMP/home-unmarked"
check "marked home may sync" no "$(marker_missing "$TMP/repo-marked" "$TMP/home-unmarked" && echo yes || echo no)"

printf 'keep=1\n_authToken=secret\n' > "$HOME/.secret-file"
printf 'safe=1\n' > "$TMP/out/.secret-file"
if sync_file "$HOME/.secret-file" "$TMP/out/.secret-file" 2>/dev/null; then
  secret_refused=no
else
  secret_refused=yes
fi
check "token file refused without overwrite" yes "$secret_refused"
check "existing destination preserved" safe=1 "$(cat "$TMP/out/.secret-file")"

printf '%s\n' '-----BEGIN RSA PRIVATE KEY-----' 'secret' '-----END RSA PRIVATE KEY-----' > "$HOME/.private-key"
if sync_file "$HOME/.private-key" "$TMP/out/.private-key" 2>/dev/null; then
  key_refused=no
else
  key_refused=yes
fi
check "private key refused" yes "$key_refused"

printf 'managed=v2\n%s\n' "$LOCAL_MARKER" > "$TMP/managed"
printf 'managed=v1\n%s\nexport PATH="/Users/nathanialhenniges/local/bin:$PATH"\n' \
  "$LOCAL_MARKER" > "$TMP/target"
copy_preserving_local "$TMP/managed" "$TMP/target" "$TMP/applied"
check "install retains machine-local block" 1 "$(grep -c 'local/bin' "$TMP/applied")"
check "install replaces managed content" 1 "$(grep -c 'managed=v2' "$TMP/applied")"

mkdir -p "$TMP/skills/source" "$TMP/skills/dest"
printf 'ordinary skill\n' > "$TMP/skills/source/SKILL.md"
sync_tree "$TMP/skills/source" "$TMP/skills/dest"
check "safe skill tree syncs" yes "$( [ -f "$TMP/skills/dest/SKILL.md" ] && echo yes || echo no)"
mkdir -p "$TMP/skills/source/nested"
printf 'linked skill\n' > "$TMP/skills/source/nested/SKILL.md"
ln -s nested "$TMP/skills/source/internal"
sync_tree "$TMP/skills/source" "$TMP/skills/dest"
check "in-tree relative symlink remains portable" yes "$( [ -f "$TMP/skills/dest/internal/SKILL.md" ] && [ ! -L "$TMP/skills/dest/internal" ] && echo yes || echo no)"
rm "$TMP/skills/source/internal"

printf 'password=ordinary\n_authToken=secret\n' > "$TMP/skills/source/unsafe.md"
printf 'keep\n' > "$TMP/skills/dest/sentinel"
if sync_tree "$TMP/skills/source" "$TMP/skills/dest" 2>/dev/null; then
  unsafe_refused=no
else
  unsafe_refused=yes
fi
check "skill token refuses whole tree before copy" yes "$unsafe_refused"
check "skill destination remains untouched" keep "$(cat "$TMP/skills/dest/sentinel")"
check "secret file not copied" no "$( [ -f "$TMP/skills/dest/unsafe.md" ] && echo yes || echo no)"
rm "$TMP/skills/source/unsafe.md"

mkdir -p "$TMP/skills/external"
printf 'external\n' > "$TMP/skills/external/file"
ln -s "$TMP/skills/external" "$TMP/skills/source/linked"
if sync_tree "$TMP/skills/source" "$TMP/skills/dest" 2>/dev/null; then
  link_refused=no
else
  link_refused=yes
fi
check "skill symlink refuses tree" yes "$link_refused"

rm "$TMP/skills/source/linked"
mkdir -p "$TMP/skills/source/.system"
printf '_authToken=cli-owned-secret\n' > "$TMP/skills/source/.system/owned"
ln -s "$TMP/skills/external" "$TMP/skills/source/.system/linked"
if sync_tree "$TMP/skills/source" "$TMP/skills/dest" --exclude=.system/ 2>/dev/null; then
  excluded_ok=yes
else
  excluded_ok=no
fi
check "excluded CLI-owned tree does not block sync" yes "$excluded_ok"
check "excluded CLI-owned tree stays excluded" no "$( [ -e "$TMP/skills/dest/.system/owned" ] && echo yes || echo no)"

# strip_pattern still applies, and applies before the rewrite.
printf 'keep=1\ntelemetry.seed=abc123\nkeep=2\n' > "$HOME/.nuxtrc"
sync_file "$HOME/.nuxtrc" "$TMP/out/.nuxtrc" '^telemetry\.seed='
check "strip pattern honoured" 0 "$(grep -c telemetry "$TMP/out/.nuxtrc")"
check "strip keeps other lines" 2 "$(wc -l < "$TMP/out/.nuxtrc" | tr -d ' ')"
printf 'telemetry.seed=only\n' > "$HOME/.nuxtrc"
sync_file "$HOME/.nuxtrc" "$TMP/out/.nuxtrc" '^telemetry\.seed='
check "all-matching file filters cleanly" 0 "$(wc -c < "$TMP/out/.nuxtrc" | tr -d ' ')"

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
