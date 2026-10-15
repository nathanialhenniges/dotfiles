#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/repo/profiles/mac-mini" "$root/home" "$root/bin"
cp "$repo_dir/mini.sh" "$root/repo/mini.sh"
cp "$repo_dir/profiles/mac-mini/.zshrc" "$root/repo/profiles/mac-mini/.zshrc"
cat > "$root/bin/uname" <<'EOF'
#!/bin/sh
echo Darwin
EOF
chmod +x "$root/bin/uname"

cat > "$root/home/.zshrc" <<'EOF'
old user shell config
# ---8<--- LOCAL ---8<---
export MINI_LOCAL_SETTING=kept
EOF
cp "$root/home/.zshrc" "$root/original"
run_mini() { env PATH="$root/bin:$PATH" HOME="$root/home" bash "$root/repo/mini.sh" "$@"; }

run_mini --dry-run >/dev/null
cmp -s "$root/home/.zshrc" "$root/original" || { echo "dry run changed .zshrc" >&2; exit 1; }
run_mini >/dev/null
cmp -s "$root/home/.zshrc.backup" "$root/original" || { echo "original backup missing or changed" >&2; exit 1; }
grep -Fxq 'export MINI_LOCAL_SETTING=kept' "$root/home/.zshrc" || { echo "local block was lost" >&2; exit 1; }
grep -Fq 'plugins=(git fzf-tab zsh-autosuggestions zsh-syntax-highlighting)' "$root/home/.zshrc" || {
  echo "full Oh My Zsh plugin setup is missing" >&2
  exit 1
}
grep -Fq 'if command -v fnm' "$root/home/.zshrc" || {
  echo "fnm is not guarded" >&2
  exit 1
}
grep -Eq 'brew install|npm install|curl .*install' "$root/repo/mini.sh" && {
  echo "mini installer installs packages or developer tools" >&2
  exit 1
}
zsh -n "$root/home/.zshrc"
cp "$root/home/.zshrc" "$root/applied"
run_mini >/dev/null
cmp -s "$root/home/.zshrc" "$root/applied" || { echo "repeat apply changed local config" >&2; exit 1; }
cmp -s "$root/home/.zshrc.backup" "$root/original" || { echo "repeat apply overwrote first backup" >&2; exit 1; }

cp "$repo_dir/sync.sh" "$root/repo/sync.sh"
cp "$repo_dir/lib/bootstrap.sh" "$root/repo/lib-bootstrap.sh"
cp "$root/repo/profiles/mac-mini/.zshrc" "$root/expected-profile"
mkdir -p "$root/repo/lib" "$root/repo/config/agent"
mv "$root/repo/lib-bootstrap.sh" "$root/repo/lib/bootstrap.sh"
printf 'keep brewfile\n' > "$root/repo/Brewfile"
printf 'keep skills\n' > "$root/repo/config/agent/sentinel"
sync_output="$(env PATH="$root/bin:$PATH" HOME="$root/home" bash "$root/repo/sync.sh" --profile mac-mini)"
grep -q '1 captured, 0 absent' <<< "$sync_output" || { echo "mini sync did not capture one file" >&2; exit 1; }
cmp -s "$root/repo/profiles/mac-mini/.zshrc" "$root/expected-profile" || { echo "mini sync captured unexpected config" >&2; exit 1; }
grep -qx 'keep brewfile' "$root/repo/Brewfile" || { echo "mini sync changed Brewfile" >&2; exit 1; }
grep -qx 'keep skills' "$root/repo/config/agent/sentinel" || { echo "mini sync changed agent skills" >&2; exit 1; }

mkdir -p "$root/home-with-backup"
printf 'current unmanaged config\n' > "$root/home-with-backup/.zshrc"
printf 'older first backup\n' > "$root/home-with-backup/.zshrc.backup"
env PATH="$root/bin:$PATH" HOME="$root/home-with-backup" bash "$root/repo/mini.sh" >/dev/null
cmp -s "$root/home-with-backup/.zshrc.backup" <(printf 'older first backup\n') || {
  echo "existing first backup was changed" >&2
  exit 1
}
recovery_backup="$(find "$root/home-with-backup" -maxdepth 1 -name '.zshrc.backup.mac-mini.*' -type f -print -quit)"
[[ -n "$recovery_backup" ]] && cmp -s "$recovery_backup" <(printf 'current unmanaged config\n') || {
  echo "unmanaged current config was not preserved" >&2
  exit 1
}

echo "Mac mini profile checks passed"
