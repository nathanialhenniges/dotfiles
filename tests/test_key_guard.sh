#!/bin/bash
# Exercises has_usable_ssh_key() from server-dev.sh against the cases that
# used to slip past the old `[[ -s ]]` check and disable password auth on a
# box with no usable key.
set -u

SRC="${1:-$HOME/Developer/nathanialhenniges/dotfiles/server-dev.sh}"

# Pull just the function out of the script so nothing else runs.
eval "$(awk '/^has_usable_ssh_key\(\) \{/,/^\}/' "$SRC")"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0

check() { # name expected(0|1) home
  local name=$1 want=$2 home=$3
  has_usable_ssh_key "$home"; local got=$?
  if [[ $got -eq $want ]]; then
    printf '  PASS  %-42s (%s)\n' "$name" "$([[ $want -eq 0 ]] && echo 'usable' || echo 'rejected')"
    pass=$((pass+1))
  else
    printf '  FAIL  %-42s want=%s got=%s\n' "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

mk() { local d="$TMP/$1"; mkdir -p "$d/.ssh"; chmod 700 "$d" "$d/.ssh"; echo "$d"; }

h=$(mk missing)                                             # no file at all
check "no authorized_keys file"            1 "$h"

h=$(mk empty);      : > "$h/.ssh/authorized_keys"
check "empty file"                         1 "$h"

h=$(mk comment);    echo '# paste your key here' > "$h/.ssh/authorized_keys"
check "comment-only placeholder"           1 "$h"

h=$(mk truncated);  echo 'ssh-ed25519 AAAAC3Nz' > "$h/.ssh/authorized_keys"
check "truncated key paste"                1 "$h"

h=$(mk privkey);    ssh-keygen -q -t ed25519 -N '' -f "$TMP/k"
cp "$TMP/k" "$h/.ssh/authorized_keys"
check "private key pasted instead of .pub" 1 "$h"

h=$(mk good);       cp "$TMP/k.pub" "$h/.ssh/authorized_keys"
check "real ed25519 public key"            0 "$h"

h=$(mk multi);      { cat "$TMP/k.pub"; echo '# a comment'; cat "$TMP/k.pub"; } > "$h/.ssh/authorized_keys"
check "real key plus comment lines"        0 "$h"

# StrictModes: only meaningful where GNU stat exists (Linux, the target OS).
if stat -c '%a' "$TMP" >/dev/null 2>&1; then
  h=$(mk loose);    cp "$TMP/k.pub" "$h/.ssh/authorized_keys"; chmod 777 "$h"
  check "good key but world-writable \$HOME"  1 "$h"
  h=$(mk loose2);   cp "$TMP/k.pub" "$h/.ssh/authorized_keys"; chmod 770 "$h/.ssh"
  check "good key but group-writable ~/.ssh"  1 "$h"
else
  echo "  SKIP  StrictModes cases (no GNU stat on this host; Linux-only path)"
fi

echo
echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
