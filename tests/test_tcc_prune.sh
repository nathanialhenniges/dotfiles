#!/bin/bash
# Exercises config/.scripts/tcc-prune against fixture TCC databases and PATH
# shims for mdfind/tccutil/launchctl/killall, so nothing here touches the real
# TCC state. Covers: classification (installed / stale / com.apple skip /
# path exists vs missing), dry-run inertness, apply (tccutil calls, sqlite
# deletes, backup), and the Spotlight-dead "prune nothing" guarantee.
set -u

SCRIPT="${1:-$(cd "$(dirname "$0")/.." && pwd)/config/.scripts/tcc-prune}"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
SQLITE3_BIN="$(command -v sqlite3)"

check() { # name expected actual
  local name=$1 want=$2 got=$3
  if [[ "$got" == "$want" ]]; then
    printf '  PASS  %-52s (%s)\n' "$name" "$want"
    pass=$((pass+1))
  else
    printf '  FAIL  %-52s want=%q got=%q\n' "$name" "$want" "$got"
    fail=$((fail+1))
  fi
}

# ── Unit: awk-extract the pure helpers ────────────────────────────────────
eval "$(awk '/^sql_escape\(\) \{/,/^\}/' "$SCRIPT")"
eval "$(awk '/^valid_bundle_id\(\) \{/,/^\}/' "$SCRIPT")"
eval "$(awk '/^path_status\(\) \{/,/^\}/' "$SCRIPT")"

check "sql_escape doubles single quotes" "O''Brien" "$(sql_escape "O'Brien")"
check "sql_escape passes plain paths"    "/usr/local/bin/x" "$(sql_escape "/usr/local/bin/x")"

vb() { valid_bundle_id "$1" && echo yes || echo no; }
check "valid id accepted"        yes "$(vb com.foo.Bar-2)"
check "empty id rejected"        no  "$(vb "")"
check "id with space rejected"   no  "$(vb "com.foo bar")"
check "id with quote rejected"   no  "$(vb "com.foo'bar")"
check "leading-dot id rejected"  no  "$(vb ".com.foo")"

touch "$TMP/exists-bin"
mkdir -p "$TMP/locked"; chmod 000 "$TMP/locked"
check "existing path -> installed"        installed    "$(path_status "$TMP/exists-bin")"
check "missing path -> stale"             stale        "$(path_status "$TMP/missing-bin")"
check "unreadable ancestor -> unverifiable" unverifiable "$(path_status "$TMP/locked/tool")"
chmod 755 "$TMP/locked"
check "/System path kept"                 system-path  "$(path_status "/System/Library/whatever")"
check "/usr path kept"                    system-path  "$(path_status "/usr/bin/ancient-ruby")"
check "/usr/local path prunable"          stale        "$(path_status "/usr/local/definitely-missing-$$")"

# ── Fixtures: DB + shims ──────────────────────────────────────────────────
make_db() { # dbfile
  sqlite3 "$1" <<SQL
CREATE TABLE access (
  service TEXT NOT NULL, client TEXT NOT NULL,
  client_type INTEGER NOT NULL, auth_value INTEGER NOT NULL DEFAULT 2,
  PRIMARY KEY (service, client, client_type));
INSERT INTO access VALUES ('kTCCServiceCamera','com.apple.Safari',0,2);
INSERT INTO access VALUES ('kTCCServiceMicrophone','com.installed.app',0,2);
INSERT INTO access VALUES ('kTCCServiceCamera','com.installed.app',0,2);
INSERT INTO access VALUES ('kTCCServiceAccessibility','com.helper.notindexed',0,2);
INSERT INTO access VALUES ('kTCCServiceScreenCapture','com.gone.app',0,2);
INSERT INTO access VALUES ('kTCCServiceAccessibility','$TMP/exists-bin',1,2);
INSERT INTO access VALUES ('kTCCServiceAccessibility','$TMP/missing-bin',1,2);
INSERT INTO access VALUES ('kTCCServiceLiverpool','com.weird.thing',2,2);
SQL
}

mkdir -p "$TMP/bin"

cat > "$TMP/bin/sqlite3" <<'EOF'
#!/bin/bash
if [[ "${FAIL_BACKUP:-0}" == "1" ]]; then
  for arg in "$@"; do
    [[ "$arg" == .backup\ * ]] && exit 1
  done
fi
exec "$SQLITE3_BIN" "$@"
EOF

cat > "$TMP/bin/mdfind" <<'EOF'
#!/bin/bash
echo "$@" >> "${MDFIND_LOG:?}"
[[ "${MDFIND_DEAD:-0}" == "1" ]] && exit 0
case "$*" in
  *com.apple.Safari*|*com.apple.TextEdit*|*com.apple.systempreferences*) echo /Applications/Fake.app ;;
  *com.installed.app*) echo /Applications/Installed.app ;;
esac
exit 0
EOF

cat > "$TMP/bin/tccutil" <<'EOF'
#!/bin/bash
echo "$@" >> "${TCCUTIL_LOG:?}"
if [[ "${REQUIRE_TCC_BACKUP:-0}" == "1" ]] &&
   ! compgen -G "${TCC_PRUNE_BACKUP_DIR:?}/TCC.db.*" >/dev/null; then
  echo "called before backup" >> "${TCCUTIL_LOG:?}"
  exit 1
fi
exit 0
EOF

cat > "$TMP/bin/launchctl" <<'EOF'
#!/bin/bash
echo "$@" >> "${LAUNCHCTL_LOG:?}"
exit 0
EOF

cat > "$TMP/bin/killall" <<'EOF'
#!/bin/bash
exit 0
EOF

# lsregister must list the sentinels, the not-Spotlight-indexed helper, and
# enough filler to clear the >=25-id health floor.
cat > "$TMP/fake-lsregister" <<'EOF'
#!/bin/bash
for i in $(seq 1 30); do printf '\tidentifier: com.filler.app%s (0x%s)\n' "$i" "$i"; done
printf '\tidentifier: com.apple.Safari (0x1)\n'
printf '\tidentifier: com.apple.TextEdit (0x2)\n'
printf '\tidentifier: com.apple.systempreferences (0x3)\n'
printf '\tidentifier: com.helper.notindexed (0x4)\n'
printf '\tidentifier: com.installed.app (0x5)\n'
EOF

chmod +x "$TMP/bin/"* "$TMP/fake-lsregister"

run_prune() { # dbfile args...
  local db="$1"; shift
  PATH="$TMP/bin:$PATH" \
  SQLITE3_BIN="$SQLITE3_BIN" \
  TCC_PRUNE_USER_DB="$db" \
  TCC_PRUNE_SYSTEM_DB="$TMP/no-system.db" \
  TCC_PRUNE_LSREGISTER="$TMP/fake-lsregister" \
   TCC_PRUNE_BACKUP_DIR="${BACKUP_DIR_OVERRIDE:-$TMP/backups}" \
  MDFIND_LOG="$TMP/mdfind.log" \
  TCCUTIL_LOG="$TMP/tccutil.log" \
  LAUNCHCTL_LOG="$TMP/launchctl.log" \
  bash "$SCRIPT" "$@"
}

rowcount() { sqlite3 "$1" 'SELECT count(*) FROM access;'; }
has() { echo "$1" | grep -qF "$2" && echo yes || echo no; }

# ── Dry run: report is right, nothing changes ─────────────────────────────
DB="$TMP/TCC.db"; make_db "$DB"
: > "$TMP/tccutil.log"

OUT=$(run_prune "$DB" 2>&1); RC=$?
check "dry run exits 0"                          0   "$RC"
check "dry run: gone app queued for reset"       yes "$(has "$OUT" "reset com.gone.app")"
check "dry run: reset line names the service"    yes "$(has "$OUT" "ScreenCapture")"
check "dry run: installed app kept"              yes "$(has "$OUT" "keep com.installed.app")"
check "dry run: non-indexed helper kept (lsregister)" yes "$(has "$OUT" "keep com.helper.notindexed")"
check "dry run: existing binary kept"            yes "$(has "$OUT" "keep $TMP/exists-bin")"
check "dry run: missing binary queued for delete" yes "$(has "$OUT" "delete $TMP/missing-bin")"
check "dry run: weird client_type reported only" yes "$(has "$OUT" "unsupported client_type 2")"
check "dry run: apple entries not listed"        no  "$(has "$OUT" "com.apple.Safari")"
check "dry run: installed app NOT queued"        no  "$(has "$OUT" "reset com.installed.app")"
check "dry run: says dry run"                    yes "$(has "$OUT" "Dry run")"
check "dry run: db untouched"                    8   "$(rowcount "$DB")"
check "dry run: tccutil never called"            0   "$(wc -l < "$TMP/tccutil.log" | tr -d ' ')"
check "dry run: plan manifest written"           yes "$([[ -f "$TMP/backups/last-plan.txt" ]] && echo yes || echo no)"

# ── Apply without a prior dry run: refused ────────────────────────────────
rm -f "$TMP/backups/last-plan.txt"
: > "$TMP/tccutil.log"
OUT=$(printf 'y\n' | run_prune "$DB" --apply 2>&1); RC=$?
check "no-dry-run apply: refused"            1   "$RC"
check "no-dry-run apply: says dry run required" yes "$(has "$OUT" "No prior dry run")"
check "no-dry-run apply: tccutil never called" 0 "$(wc -l < "$TMP/tccutil.log" | tr -d ' ')"
check "no-dry-run apply: db untouched"       8   "$(rowcount "$DB")"

run_prune "$DB" >/dev/null 2>&1  # regenerate the manifest

# ── Apply after the candidate set changed: refused ────────────────────────
sqlite3 "$DB" "INSERT INTO access VALUES ('kTCCServiceCamera','com.gone.extra',0,2);"
: > "$TMP/tccutil.log"
OUT=$(printf 'y\n' | run_prune "$DB" --apply 2>&1); RC=$?
check "changed-set apply: refused"           1   "$RC"
check "changed-set apply: says set changed"  yes "$(has "$OUT" "changed since")"
check "changed-set apply: tccutil never called" 0 "$(wc -l < "$TMP/tccutil.log" | tr -d ' ')"
sqlite3 "$DB" "DELETE FROM access WHERE client='com.gone.extra';"

# ── Apply: resets via tccutil, deletes via sqlite, backup taken ───────────
: > "$TMP/tccutil.log"
OUT=$(printf 'y\n' | run_prune "$DB" --apply 2>&1); RC=$?
check "apply exits 0"                        0 "$RC"
check "apply: tccutil called once"           1 "$(wc -l < "$TMP/tccutil.log" | tr -d ' ')"
check "apply: tccutil reset All com.gone.app" "reset All com.gone.app" "$(cat "$TMP/tccutil.log")"
check "apply: stale path row deleted"        0 "$(sqlite3 "$DB" "SELECT count(*) FROM access WHERE client='$TMP/missing-bin';")"
check "apply: existing path row intact"      1 "$(sqlite3 "$DB" "SELECT count(*) FROM access WHERE client='$TMP/exists-bin';")"
check "apply: installed app rows intact"     2 "$(sqlite3 "$DB" "SELECT count(*) FROM access WHERE client='com.installed.app';")"
check "apply: only the one row removed"      7 "$(rowcount "$DB")"
check "apply: user tccd restarted"           yes "$(has "$(cat "$TMP/launchctl.log")" "com.apple.tccd")"

BACKUP=$(find "$TMP/backups" -type f -name 'TCC.db.*' 2>/dev/null | head -1)
check "apply: backup file exists"            yes "$([[ -n "$BACKUP" ]] && echo yes || echo no)"
check "apply: backup has pre-delete rows"    8   "$(rowcount "$BACKUP")"
check "apply: plan manifest consumed"        no  "$([[ -f "$TMP/backups/last-plan.txt" ]] && echo yes || echo no)"

# ── Bundle-only apply backs up before tccutil ──────────────────────────────
DB_BUNDLE="$TMP/TCC-bundle-only.db"; make_db "$DB_BUNDLE"
sqlite3 "$DB_BUNDLE" "DELETE FROM access WHERE client='$TMP/missing-bin';"
OUT=$(BACKUP_DIR_OVERRIDE="$TMP/bundle-backups" run_prune "$DB_BUNDLE" 2>&1); RC=$?
check "bundle-only dry run exits 0"           0 "$RC"
: > "$TMP/tccutil.log"
OUT=$(printf 'y\n' | BACKUP_DIR_OVERRIDE="$TMP/bundle-backups" REQUIRE_TCC_BACKUP=1 run_prune "$DB_BUNDLE" --apply 2>&1); RC=$?
check "bundle-only apply exits 0"             0 "$RC"
check "bundle-only apply has backup before reset" no "$(has "$(cat "$TMP/tccutil.log")" "called before backup")"
check "bundle-only apply resets once"         1 "$(grep -c '^reset All ' "$TMP/tccutil.log" || true)"

# ── Backup failure aborts before resets or database writes ─────────────────
DB4="$TMP/TCC4.db"; make_db "$DB4"
sqlite3 "$DB4" "DELETE FROM access WHERE client='$TMP/missing-bin';"
OUT=$(run_prune "$DB4" 2>&1); RC=$?
check "backup-failure dry run exits 0"        0 "$RC"
: > "$TMP/tccutil.log"
OUT=$(printf 'y\n' | FAIL_BACKUP=1 run_prune "$DB4" --apply 2>&1); RC=$?
check "backup failure exits nonzero"          0 "$([[ $RC -ne 0 ]] && echo 0 || echo 1)"
check "backup failure: no tccutil reset"      0 "$(wc -l < "$TMP/tccutil.log" | tr -d ' ')"
check "backup failure: db unchanged"          7 "$(rowcount "$DB4")"

# ── Apply with nothing stale: no-op, no confirm needed ────────────────────
# The tccutil shim doesn't mutate the DB like the real one would, so simulate
# its effect before re-running.
sqlite3 "$DB" "DELETE FROM access WHERE client='com.gone.app';"
: > "$TMP/tccutil.log"
OUT=$(run_prune "$DB" --apply </dev/null 2>&1); RC=$?
check "second apply: nothing to prune"       yes "$(has "$OUT" "Nothing to prune")"
check "second apply: exits 0"                0   "$RC"

# ── Spotlight dead: prune nothing, say so ─────────────────────────────────
DB2="$TMP/TCC2.db"; make_db "$DB2"
: > "$TMP/tccutil.log"
OUT=$(MDFIND_DEAD=1 run_prune "$DB2" 2>&1); RC=$?
check "spotlight dead: exits 0"              0   "$RC"
check "spotlight dead: degraded notice"      yes "$(has "$OUT" "Spotlight index unavailable")"
check "spotlight dead: no bundle resets"     no  "$(has "$OUT" "reset com.gone.app")"
check "spotlight dead: gone app kept-unverified" yes "$(has "$OUT" "com.gone.app — could not verify")"

# ── Circuit breaker: mass staleness refuses to apply ──────────────────────
DB3="$TMP/TCC3.db"
sqlite3 "$DB3" <<SQL
CREATE TABLE access (
  service TEXT NOT NULL, client TEXT NOT NULL,
  client_type INTEGER NOT NULL, auth_value INTEGER NOT NULL DEFAULT 2,
  PRIMARY KEY (service, client, client_type));
INSERT INTO access VALUES ('kTCCServiceCamera','com.gone.one',0,2);
INSERT INTO access VALUES ('kTCCServiceCamera','com.gone.two',0,2);
INSERT INTO access VALUES ('kTCCServiceCamera','com.gone.three',0,2);
INSERT INTO access VALUES ('kTCCServiceCamera','com.installed.app',0,2);
SQL
: > "$TMP/tccutil.log"
OUT=$(printf 'y\n' | MDFIND_DEAD=0 run_prune "$DB3" --apply 2>&1); RC=$?
check "breaker: apply refused"               1 "$RC"
check "breaker: names the circuit breaker"   yes "$(has "$OUT" "circuit breaker")"
check "breaker: tccutil never called"        0 "$(wc -l < "$TMP/tccutil.log" | tr -d ' ')"
check "breaker: db untouched"                4 "$(rowcount "$DB3")"

echo
echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
