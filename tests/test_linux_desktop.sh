#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
installer="$repo_dir/linux-desktop.sh"
profile_dir="$repo_dir/profiles/linux-desktop"
sync_script="$repo_dir/sync.sh"
test_root="$(mktemp -d)"
test_root="$(cd "$test_root" && pwd -P)"
trap 'rm -rf "$test_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mode_of() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

fake_bin="$test_root/bin"
home_dir="$test_root/home"
state_dir="$home_dir/.local/state"
mkdir -p "$fake_bin" "$home_dir"
cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
printf 'Linux\n'
EOF
chmod +x "$fake_bin/uname"

run_installer() {
  env PATH="$fake_bin:$PATH" HOME="$home_dir" XDG_STATE_HOME="$state_dir" "$installer" "$@"
}

# Keeping the profile outside config/ prevents the existing broad-copy Mac and
# Codespaces installers from discovering and copying it into ~/linux-desktop/.
if find "$repo_dir/config/linux-desktop" -type f -print -quit 2>/dev/null | grep -q .; then
  fail "desktop profile leaked into config/"
fi
[[ -f "$profile_dir/.zshrc" && -f "$profile_dir/.aliases" ]] || fail "desktop profile is incomplete"

dry_output="$(run_installer --dry-run)"
[[ "$dry_output" == *"No files changed"* ]] || fail "dry run did not finish"
[[ ! -e "$home_dir/.zshrc" && ! -e "$state_dir" ]] || fail "dry run wrote files"

run_installer >/dev/null
cmp -s "$profile_dir/.zshrc" "$home_dir/.zshrc" || fail "zshrc not applied"
cmp -s "$profile_dir/.aliases" "$home_dir/.aliases" || fail "aliases not applied"
cmp -s "$profile_dir/.config/ghostty/config" "$home_dir/.config/ghostty/config" || fail "Ghostty config not applied"
grep -Fxq 'command = direct:/usr/bin/zsh' "$home_dir/.config/ghostty/config" || fail "Ghostty does not launch Zsh directly"
if grep -Eq '^(macos-|background-blur)|cmd\+' "$home_dir/.config/ghostty/config"; then
  fail "macOS-only or GNOME-unsafe Ghostty option leaked into Linux"
fi
cmp -s "$repo_dir/config/.config/ohmyposh/mrdemonwolf.omp.json" \
  "$home_dir/.config/ohmyposh/mrdemonwolf.omp.json" || fail "Oh My Posh theme not applied"
[[ ! -e "$home_dir/.gitconfig" && ! -e "$home_dir/agent" && ! -e "$home_dir/server" && \
   ! -e "$home_dir/sharedhosting" && ! -e "$home_dir/linux-desktop" ]] || fail "excluded config was copied"
if grep -Fxq '  ".gitconfig"' "$sync_script" || grep -Fxq '  ".npmrc"' "$sync_script"; then
  fail "credential-prone config is still in the public sync allowlist"
fi
[[ "$(mode_of "$home_dir/.zshrc")" == "644" ]] || fail "zshrc mode is not 0644"

second_output="$(run_installer)"
[[ "$second_output" == *"already current"* ]] || fail "second run was not idempotent"

# Equal content with unsafe permissions is not current: .zshrc executes code.
chmod 0666 "$home_dir/.zshrc"
run_installer >/dev/null
[[ "$(mode_of "$home_dir/.zshrc")" == "644" ]] || fail "unsafe zshrc mode was not repaired"

printf 'user change\n' > "$home_dir/.zshrc"
run_installer >/dev/null
backup_count="$(find "$state_dir/linux-setup/backups" -type f -path '*/.zshrc' | wc -l | tr -d ' ')"
[[ "$backup_count" -eq 2 ]] || fail "mode and content changes were not backed up"
user_backup_found=false
while IFS= read -r backup_file; do
  if grep -qxF 'user change' "$backup_file"; then
    user_backup_found=true
    break
  fi
done < <(find "$state_dir/linux-setup/backups" -type f -path '*/.zshrc')
[[ "$user_backup_found" == true ]] || fail "backup did not preserve the user change"

# All mappings must pass preflight before the first target is written.
preflight_home="$test_root/preflight-home"
preflight_outside="$test_root/preflight-outside"
mkdir -p "$preflight_home" "$preflight_outside"
ln -s "$preflight_outside" "$preflight_home/.config"
if env PATH="$fake_bin:$PATH" HOME="$preflight_home" \
  XDG_STATE_HOME="$preflight_home/.local/state" "$installer" >/dev/null 2>&1; then
  fail "later symbolic-link conflict was accepted"
fi
[[ ! -e "$preflight_home/.zshrc" && ! -e "$preflight_home/.aliases" ]] || \
  fail "preflight failure left earlier mappings applied"

unsafe_home="$test_root/unsafe-home"
outside_file="$test_root/outside"
mkdir -p "$unsafe_home"
printf 'outside\n' > "$outside_file"
ln -s "$outside_file" "$unsafe_home/.zshrc"
if env PATH="$fake_bin:$PATH" HOME="$unsafe_home" \
  XDG_STATE_HOME="$unsafe_home/.local/state" "$installer" >/dev/null 2>&1; then
  fail "symbolic-link destination was accepted"
fi
[[ "$(cat "$outside_file")" == "outside" ]] || fail "symbolic-link target changed"

external_home="$test_root/external-home"
external_state="$test_root/external-state"
mkdir -p "$external_home" "$external_state"
if env PATH="$fake_bin:$PATH" HOME="$external_home" XDG_STATE_HOME="$external_state" \
  "$installer" >/dev/null 2>&1; then
  fail "XDG_STATE_HOME outside HOME was accepted"
fi
[[ ! -e "$external_home/.zshrc" ]] || fail "external state rejection wrote a target"

state_link_home="$test_root/state-link-home"
state_link_outside="$test_root/state-link-outside"
mkdir -p "$state_link_home" "$state_link_outside"
ln -s "$state_link_outside" "$state_link_home/.local"
if env -u XDG_STATE_HOME PATH="$fake_bin:$PATH" HOME="$state_link_home" \
  "$installer" >/dev/null 2>&1; then
  fail "symbolic-link state path was accepted"
fi
if find "$state_link_outside" -mindepth 1 -print -quit | grep -q .; then
  fail "symbolic-link state target was written"
fi

printf 'PASS: Linux desktop profile safety checks\n'
