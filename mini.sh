#!/usr/bin/env bash
set -euo pipefail

# Apply only the Mac mini shell profile; install no packages or developer tools.
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source_file="$repo_dir/profiles/mac-mini/.zshrc"
dry_run=false

case "${1:-}" in
  "") ;;
  --dry-run) dry_run=true ;;
  -h|--help)
    echo "Usage: ./mini.sh [--dry-run]"
    echo "Applies the minimal Mac mini .zshrc without installing packages."
    exit 0
    ;;
  *) echo "error: unknown option: $1" >&2; exit 1 ;;
esac

[[ "$(uname -s)" == "Darwin" ]] || { echo "error: Mac mini profile supports macOS only" >&2; exit 1; }
[[ "$(id -u)" -ne 0 ]] || { echo "error: run as your normal user, not root" >&2; exit 1; }
[[ -f "$source_file" && ! -L "$source_file" ]] || { echo "error: missing or unsafe profile: $source_file" >&2; exit 1; }
[[ -n "${HOME:-}" && "$HOME" == /* && "$HOME" != "/" && -d "$HOME" ]] || {
  echo "error: HOME must be an existing absolute directory" >&2
  exit 1
}

target="$HOME/.zshrc"
[[ ! -L "$target" ]] || { echo "error: refusing symbolic-link destination: $target" >&2; exit 1; }
[[ ! -e "$target" || -f "$target" ]] || { echo "error: destination is not a regular file: $target" >&2; exit 1; }
[[ ! -L "$target.backup" ]] || { echo "error: refusing symbolic-link backup: $target.backup" >&2; exit 1; }
[[ ! -e "$target.backup" || -f "$target.backup" ]] || { echo "error: backup is not a regular file: $target.backup" >&2; exit 1; }

if [[ -f "$target" ]] && cmp -s "$source_file" "$target"; then
  echo "Mac mini profile is already current."
  exit 0
fi
if [[ "$dry_run" == true ]]; then
  echo "Would apply $target"
  exit 0
fi

if [[ -f "$target" && ! -e "$target.backup" ]]; then
  cp -p "$target" "$target.backup"
  echo "Backed up $target -> $target.backup"
elif [[ -f "$target" ]] && ! grep -qF '# ---8<--- LOCAL ---8<---' "$target"; then
  recovery_backup="$(mktemp "$target.backup.mac-mini.XXXXXX")"
  cp -p "$target" "$recovery_backup"
  echo "Saved unmanaged config $target -> $recovery_backup"
fi

temporary_file="$(mktemp "$target.tmp.XXXXXX")"
trap 'rm -f "$temporary_file"' EXIT
if [[ -f "$target" ]] && grep -qF '# ---8<--- LOCAL ---8<---' "$target"; then
  awk '{ print } $0 == "# ---8<--- LOCAL ---8<---" { exit }' "$source_file" > "$temporary_file"
  awk -v marker='# ---8<--- LOCAL ---8<---' 'found { print } $0 == marker { found = 1 }' "$target" >> "$temporary_file"
else
  cp "$source_file" "$temporary_file"
fi
chmod 644 "$temporary_file"
mv -f "$temporary_file" "$target"
trap - EXIT
echo "Applied $target; restart the shell to use it."
