#!/bin/bash
# Exercises the --agent-setup plugin wiring in server-dev.sh.
#
# The bug: AGENT_PLUGINS named `expo-deployment@expo-plugins`, every install was
# wrapped in `&>/dev/null || substep "... (already installed or unavailable)"`,
# and the marketplace add was wrapped the same way. When the expo marketplace
# failed to register, the two installs under it failed too — and the log said
# the same reassuring thing it says for a plugin you already have. A whole
# provisioning run on chi-01 reported success while installing nothing.
#
# So two things are checked here: that the arrays cannot drift apart again
# unnoticed (preflight), and that a real failure no longer looks like a no-op
# (agent_try).
set -u

SCRIPT="${1:-$HOME/Developer/nathanialhenniges/dotfiles/server-dev.sh}"
SETTINGS="$(dirname "$SCRIPT")/config/agent/claude/settings.json"

# Pull in only the arrays and the two functions — sourcing server-dev.sh whole
# would run the installer.
log()     { :; }
# Mirrors lib/bootstrap.sh — it prints, and the printing is half of what these
# tests are about, so the stub must print too.
substep() { LAST_SUBSTEP="$*"; echo "    $*"; }
eval "$(awk '/^AGENT_MARKETPLACES=\(/,/^\)/'          "$SCRIPT")"
eval "$(awk '/^AGENT_PLUGINS=\(/,/^\)/'               "$SCRIPT")"
eval "$(awk '/^AGENT_SETUP_FAILURES=\(\)/'            "$SCRIPT")"
eval "$(awk '/^agent_try\(\) \{/,/^\}/'               "$SCRIPT")"
eval "$(awk '/^agent_plugin_preflight\(\) \{/,/^\}/'  "$SCRIPT")"

pass=0; fail=0

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

echo "== arrays parsed =="
check "marketplaces found" "yes" "$([[ ${#AGENT_MARKETPLACES[@]} -gt 0 ]] && echo yes || echo no)"
check "plugins found"      "yes" "$([[ ${#AGENT_PLUGINS[@]} -gt 0 ]] && echo yes || echo no)"

echo "== every entry carries its alias =="
# `owner/repo=alias` — a bare `owner/repo` would make preflight compare against
# the repo path and silently pass nothing.
malformed=""
for m in "${AGENT_MARKETPLACES[@]}"; do
  [[ "$m" == */*=* ]] || malformed+="$m "
done
check "all marketplaces are owner/repo=alias" "" "$malformed"

echo "== preflight on the real arrays =="
agent_plugin_preflight >/dev/null 2>&1
check "real arrays agree" "0" "$?"

echo "== preflight catches the chi-01 bug =="
# The exact shape of the original defect: a plugin pointing at an alias that no
# marketplace registers.
(
  AGENT_PLUGINS=(expo-deployment@expo-plugins)
  AGENT_MARKETPLACES=(expo/skills=something-else)
  agent_plugin_preflight >/dev/null 2>&1
)
check "unregistered marketplace rejected" "1" "$?"

echo "== agent_try tells the three cases apart =="
AGENT_SETUP_FAILURES=()

agent_try "ok-step" true
check "success reported plainly"   "ok-step" "$LAST_SUBSTEP"
check "success not counted failed" "0"       "${#AGENT_SETUP_FAILURES[@]}"

agent_try "dup-step" bash -c 'echo "Plugin already installed"; exit 1'
check "already-present distinguished" "dup-step (already present)" "$LAST_SUBSTEP"
check "already-present not a failure" "0"  "${#AGENT_SETUP_FAILURES[@]}"

agent_try "broken-step" bash -c 'echo "fatal: repository not found"; exit 1' >/dev/null
check "real failure counted" "1"            "${#AGENT_SETUP_FAILURES[@]}"
check "real failure named"   "broken-step"  "${AGENT_SETUP_FAILURES[0]}"

# The whole point: the operator must be able to see WHY, not just that.
out=$(agent_try "loud-step" bash -c 'echo "fatal: repository not found"; exit 1')
check "failure prints the error" "yes" "$(grep -q 'repository not found' <<<"$out" && echo yes || echo no)"
check "failure is marked FAILED" "yes" "$(grep -q 'FAILED' <<<"$out" && echo yes || echo no)"

echo "== settings.json agrees with the arrays =="
if command -v python3 >/dev/null 2>&1 && [[ -f "$SETTINGS" ]]; then
  # enabledPlugins is the declarative half of the same install: if it lists a
  # plugin the script never installs (or vice versa), one of them is wrong.
  drift=$(python3 - "$SETTINGS" <<PY "${AGENT_PLUGINS[@]}"
import json, sys
settings = json.load(open(sys.argv[1]))
declared = set(settings.get("enabledPlugins", {}))
scripted = set(sys.argv[2:])
print(" ".join(sorted(declared ^ scripted)))
PY
)
  check "enabledPlugins == AGENT_PLUGINS" "" "$drift"

  # Every marketplace an enabled plugin depends on must be declared, or the
  # plugin silently never loads on a fresh box.
  missing=$(python3 - "$SETTINGS" <<'PY'
import json, sys
settings = json.load(open(sys.argv[1]))
known = set(settings.get("extraKnownMarketplaces", {}))
known.add("claude-plugins-official")  # built in, never declared
needed = {p.split("@")[-1] for p in settings.get("enabledPlugins", {})}
print(" ".join(sorted(needed - known)))
PY
)
  check "every enabled marketplace declared" "" "$missing"

  unused=$(python3 - "$SETTINGS" <<'PY'
import json, sys
settings = json.load(open(sys.argv[1]))
known = set(settings.get("extraKnownMarketplaces", {}))
used = {p.split("@")[-1] for p in settings.get("enabledPlugins", {})}
print(" ".join(sorted(known - used)))
PY
)
  check "no marketplace declared but unused" "" "$unused"
else
  echo "  SKIP  settings.json cross-check (needs python3)"
fi

echo "== --agent-setup-only parses and stops early =="
# The flag is only useful if it (a) implies --agent-setup, so the step it names
# actually runs, and (b) exits before create_home_dirs — "only" has to mean only.
flags=$(bash -c '
  set -e
  set -- --agent-setup-only          # the parser reads $@, so seed it first
  usage() { :; }
  eval "$(awk "/^INSTALL_AI=\"\"/,/^done\$/" "$0")"
  echo "AGENT_SETUP=$AGENT_SETUP AGENT_SETUP_ONLY=$AGENT_SETUP_ONLY"
' "$SCRIPT" 2>&1) || flags="parse failed: $flags"
check "--agent-setup-only implies --agent-setup" "AGENT_SETUP=1 AGENT_SETUP_ONLY=1" "$flags"

check "only-branch exits before the full run" "yes" \
  "$(awk '/^if \[\[ -n "\$AGENT_SETUP_ONLY" \]\]; then/,/^fi/' "$SCRIPT" | grep -q 'exit 0' && echo yes || echo no)"
# On a box with no Node the CLIs can't be installed, so agent_setup would copy
# settings and skills and then skip every plugin — configured-looking and not
# configured, which is the failure this whole file exists to prevent.
only_branch=$(awk '/^if \[\[ -n "\$AGENT_SETUP_ONLY" \]\]; then/,/^fi/' "$SCRIPT")
check "bare box refused, not half-done" "yes" \
  "$(grep -q 'npm_global_cmd' <<<"$only_branch" && grep -q 'exit 1' <<<"$only_branch" && echo yes || echo no)"
check "refusal names the right flag" "yes" \
  "$(grep -q -- ') --agent-setup"' <<<"$only_branch" && echo yes || echo no)"

check "only-branch runs before create_home_dirs" "yes" \
  "$([[ $(grep -n 'AGENT_SETUP_ONLY" \]\]; then' "$SCRIPT" | tail -1 | cut -d: -f1) -lt \
      $(grep -n '^create_home_dirs' "$SCRIPT" | tail -1 | cut -d: -f1) ]] && echo yes || echo no)"

# The flag is advertised in three places; a flag nobody can discover is a flag
# nobody uses.
check "listed in --help"        "yes" "$(grep -q -- '--agent-setup-only        run ONLY' "$SCRIPT" && echo yes || echo no)"
check "listed in unknown-opt hint" "yes" "$(grep -q -- 'Try: --ai, --pnpm, --agent-setup, --agent-setup-only' "$SCRIPT" && echo yes || echo no)"
check "offered in the failure summary" "yes" "$(grep -q 'RAW_URL) --agent-setup-only' "$SCRIPT" && echo yes || echo no)"

echo ""
echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]]
