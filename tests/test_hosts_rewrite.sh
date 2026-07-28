#!/bin/bash
# Exercises the /etc/hosts rewrite logic from set_hostname() in server-dev.sh.
# The awk transform is extracted rather than mocking sudo, so this runs safely
# on any machine and never touches the real /etc/hosts.
set -u

pass=0; fail=0
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Same transform as set_hostname(). Kept in sync by test_matches_source below.
rewrite() { # <hosts-file> <replacement-line>
  awk -v repl="$2" \
    '/^127\.0\.1\.1/ { if (!done) { print repl; done=1 } ; next }
     { print }
     END { if (!done) print repl }' "$1"
}

line_for() { # <name> -> the 127.0.1.1 line set_hostname would build
  local fqdn="$1" short="${1%%.*}"
  if [[ "$fqdn" == *.* ]]; then printf '127.0.1.1\t%s %s' "$fqdn" "$short"
  else printf '127.0.1.1\t%s' "$short"; fi
}

check() { # name expected actual
  if [[ "$2" == "$3" ]]; then
    printf '  PASS  %s\n' "$1"; pass=$((pass+1))
  else
    printf '  FAIL  %s\n        want: %q\n        got:  %q\n' "$1" "$2" "$3"; fail=$((fail+1))
  fi
}

# --- Ubuntu cloud image default -------------------------------------------
cat > "$TMP/h1" <<'EOF'
127.0.0.1 localhost
127.0.1.1 oldname

::1 ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
EOF
out=$(rewrite "$TMP/h1" "$(line_for chi-01)")
check "replaces existing 127.0.1.1, keeps everything else" \
  "$(printf '127.0.0.1 localhost\n127.0.1.1\tchi-01\n\n::1 ip6-localhost ip6-loopback\nff02::1 ip6-allnodes')" \
  "$out"
check "exactly one 127.0.1.1 line remains" 1 "$(grep -c '^127\.0\.1\.1' <<<"$out")"
check "IPv6 loopback entries survive" 1 "$(grep -c 'ip6-localhost' <<<"$out")"

# --- no 127.0.1.1 line at all ---------------------------------------------
printf '127.0.0.1 localhost\n' > "$TMP/h2"
out=$(rewrite "$TMP/h2" "$(line_for chi-01)")
check "appends when no 127.0.1.1 line exists" \
  "$(printf '127.0.0.1 localhost\n127.0.1.1\tchi-01')" "$out"

# --- FQDN form: Debian wants FQDN first, then short ------------------------
out=$(rewrite "$TMP/h1" "$(line_for chi-01.mrdemonwolf.com)")
check "FQDN before short name (hostname -f reads this order)" \
  "127.0.1.1	chi-01.mrdemonwolf.com chi-01" \
  "$(grep '^127\.0\.1\.1' <<<"$out")"

# --- duplicate 127.0.1.1 lines collapse to one -----------------------------
printf '127.0.0.1 localhost\n127.0.1.1 a\n127.0.1.1 b\n' > "$TMP/h3"
out=$(rewrite "$TMP/h3" "$(line_for chi-01)")
check "collapses duplicate 127.0.1.1 lines to one" 1 "$(grep -c '^127\.0\.1\.1' <<<"$out")"

# --- sed-hostile characters ------------------------------------------------
# A literal & in a sed replacement expands to the whole match. awk must not.
out=$(rewrite "$TMP/h1" '127.0.1.1	a&b')
check "ampersand is literal, not a sed backreference" "127.0.1.1	a&b" \
  "$(grep '^127\.0\.1\.1' <<<"$out")"

# --- 127.0.0.1 is never clobbered -----------------------------------------
out=$(rewrite "$TMP/h1" "$(line_for chi-01)")
check "127.0.0.1 localhost untouched" "127.0.0.1 localhost" \
  "$(grep '^127\.0\.0\.1' <<<"$out")"

# --- guard: the awk in the script still matches the one tested here --------
SRC="${1:-$(dirname "$0")/../server-dev.sh}"
if grep -q 'if (!done) { print repl; done=1 }' "$SRC" \
   && grep -q 'END { if (!done) print repl }' "$SRC"; then
  printf '  PASS  %s\n' "awk transform still matches server-dev.sh"; pass=$((pass+1))
else
  printf '  FAIL  %s\n' "awk transform drifted from server-dev.sh — update this test"; fail=$((fail+1))
fi

echo
echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
