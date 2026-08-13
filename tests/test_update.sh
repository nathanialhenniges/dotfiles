#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

fixture="$test_root/dotfiles"
remote="$test_root/remote.git"
publisher="$test_root/publisher"
fake_bin="$test_root/bin"
home_dir="$test_root/home"
mkdir -p "$fixture/config/.config/ghostty" "$fixture/config/.config/ohmyposh" \
  "$fixture/config/.scripts" "$fixture/profiles/linux-desktop/.config/ghostty" \
  "$fixture/tests" "$fake_bin" "$home_dir"

cp "$repo_dir/install.sh" "$repo_dir/update.sh" "$repo_dir/linux-desktop.sh" "$fixture/"
for file in .zshrc .zprofile .p10k.zsh .profile .aliases .nuxtrc; do
  cp "$repo_dir/config/$file" "$fixture/config/$file"
done
cp "$repo_dir/config/.config/ghostty/config" "$fixture/config/.config/ghostty/config"
cp "$repo_dir/config/.config/ohmyposh/mrdemonwolf.omp.json" "$fixture/config/.config/ohmyposh/"
cp "$repo_dir/config/.scripts/new-video" "$repo_dir/config/.scripts/obs-backup" \
  "$repo_dir/config/.scripts/yt-video-backup" "$fixture/config/.scripts/"
cp "$repo_dir/profiles/linux-desktop/.zshrc" "$repo_dir/profiles/linux-desktop/.aliases" \
  "$fixture/profiles/linux-desktop/"
cp "$repo_dir/profiles/linux-desktop/.config/ghostty/config" \
  "$fixture/profiles/linux-desktop/.config/ghostty/config"

cat > "$fake_bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${FAKE_UNAME:-Darwin}"
EOF
cat > "$fake_bin/id" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "-u" ]; then printf '501\n'; else exec /usr/bin/id "$@"; fi
EOF
chmod +x "$fixture/install.sh" "$fixture/update.sh" "$fixture/linux-desktop.sh" "$fake_bin/uname" "$fake_bin/id"

git -C "$fixture" init -q -b main
git -C "$fixture" add .
git -C "$fixture" -c user.name=Test -c user.email=test@example.com \
  -c commit.gpgsign=false commit -qm initial
git clone -q --bare "$fixture" "$remote"
git -C "$fixture" remote add origin https://github.com/nathanialhenniges/dotfiles.git
git -C "$fixture" config "url.file://$remote.insteadOf" https://github.com/nathanialhenniges/dotfiles.git

git clone -q "$remote" "$publisher"
printf 'remote update\n' > "$publisher/REMOTE_MARKER"
git -C "$publisher" add REMOTE_MARKER
git -C "$publisher" -c user.name=Test -c user.email=test@example.com \
  -c commit.gpgsign=false commit -qm remote
git -C "$publisher" push -q origin main

printf 'original user zsh\n' > "$home_dir/.zshrc"
output="$(env PATH="$fake_bin:$PATH" HOME="$home_dir" "$fixture/update.sh")"
[[ -f "$fixture/REMOTE_MARKER" ]] || fail "origin/main was not fast-forwarded"
cmp -s "$fixture/config/.zshrc" "$home_dir/.zshrc" || fail "macOS zshrc was not applied"
grep -qxF 'original user zsh' "$home_dir/.zshrc.backup" || fail "original macOS file was not backed up"
cmp -s "$fixture/config/.config/ghostty/config" \
  "$home_dir/Library/Application Support/com.mitchellh.ghostty/config" || fail "macOS Ghostty mapping failed"
[[ "$output" == *"No commit or push was made"* ]] || fail "update completion was unclear"
[[ ! -e "$home_dir/server" && ! -e "$home_dir/agent" && ! -e "$home_dir/sharedhosting" ]] || \
  fail "excluded profile was applied"

printf 'local second edit\n' > "$home_dir/.zshrc"
env PATH="$fake_bin:$PATH" HOME="$home_dir" "$fixture/install.sh" --apply-only >/dev/null
grep -qxF 'original user zsh' "$home_dir/.zshrc.backup" || fail "existing backup was overwritten"

dry_home="$test_root/dry-home"
mkdir -p "$dry_home"
dry_output="$(env PATH="$fake_bin:$PATH" HOME="$dry_home" "$fixture/update.sh" --dry-run)"
[[ "$dry_output" == *"Would fetch origin/main"* && "$dry_output" == *"No files changed"* ]] || \
  fail "macOS dry run was not complete"
[[ -z "$(find "$dry_home" -mindepth 1 -print -quit)" ]] || fail "dry run wrote to HOME"

unsafe_home="$test_root/unsafe-home"
outside="$test_root/outside"
mkdir -p "$unsafe_home" "$outside"
ln -s "$outside" "$unsafe_home/.config"
if unsafe_output="$(env PATH="$fake_bin:$PATH" HOME="$unsafe_home" "$fixture/install.sh" --apply-only 2>&1)"; then
  fail "symbolic-link destination was accepted: $unsafe_output"
fi
[[ ! -e "$unsafe_home/.zshrc" ]] || fail "failed preflight partially applied files"

linux_home="$test_root/linux-home"
mkdir -p "$linux_home"

# A bare Linux run must refuse. mrdemonwolf-dev and kommit-dev are Linux but run
# the server profile, so assuming "desktop" would overwrite their shell config
# with 100+ lines of the wrong file.
if bare_linux="$(env FAKE_UNAME=Linux PATH="$fake_bin:$PATH" HOME="$linux_home" \
    "$fixture/update.sh" --dry-run 2>&1)"; then
  fail "bare Linux run was accepted without --profile: $bare_linux"
fi
[[ "$bare_linux" == *"name the profile"* ]] || fail "Linux refusal did not explain itself: $bare_linux"
[[ -z "$(find "$linux_home" -mindepth 1 -print -quit)" ]] || fail "refused Linux run wrote to HOME"

if bad_profile="$(env FAKE_UNAME=Linux PATH="$fake_bin:$PATH" HOME="$linux_home" \
    "$fixture/update.sh" --profile server --dry-run 2>&1)"; then
  fail "unknown Linux profile was accepted: $bad_profile"
fi

# macOS must keep working with no flag at all.
mac_noflag_home="$test_root/mac-noflag"
mkdir -p "$mac_noflag_home"
mac_noflag="$(env PATH="$fake_bin:$PATH" HOME="$mac_noflag_home" "$fixture/update.sh" --dry-run 2>&1)" || \
  fail "macOS dry run started requiring a profile"
[[ "$mac_noflag" == *"No files changed"* ]] || fail "macOS dry run regressed: $mac_noflag"

linux_output="$(env FAKE_UNAME=Linux PATH="$fake_bin:$PATH" HOME="$linux_home" \
  "$fixture/update.sh" --profile linux-desktop --dry-run)"
[[ "$linux_output" == *"would apply .zshrc"* && "$linux_output" == *"No files changed"* && \
   "$linux_output" != *"Library/Application Support"* ]] || \
  fail "Linux updater did not dispatch only the desktop profile: $linux_output"
[[ -z "$(find "$linux_home" -mindepth 1 -print -quit)" ]] || fail "Linux dry run wrote to HOME"

printf 'dirty\n' > "$fixture/dirty"
if env PATH="$fake_bin:$PATH" HOME="$home_dir" "$fixture/update.sh" --dry-run >/dev/null 2>&1; then
  fail "dirty worktree was accepted"
fi
rm "$fixture/dirty"

git -C "$fixture" config remote.origin.url https://github.com/someone-else/dotfiles.git
if env PATH="$fake_bin:$PATH" HOME="$home_dir" "$fixture/update.sh" --dry-run >/dev/null 2>&1; then
  fail "wrong origin was accepted"
fi

git -C "$fixture" config remote.origin.url https://github.com/nathanialhenniges/dotfiles.git
git -C "$fixture" switch -qc not-main
if env PATH="$fake_bin:$PATH" HOME="$home_dir" "$fixture/update.sh" --dry-run >/dev/null 2>&1; then
  fail "non-main branch was accepted"
fi

printf 'PASS: cross-platform updater safety checks\n'
