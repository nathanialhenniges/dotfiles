#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
dry_run=false
case "${1:-}" in
  '') ;;
  --dry-run) dry_run=true ;;
  *) echo 'Usage: server-apply.sh [--dry-run]' >&2; exit 1 ;;
esac
[[ $# -le 1 && "$(uname -s)" == Linux ]] || { echo 'Requires Linux and at most one option.' >&2; exit 1; }
[[ -n "${HOME:-}" && "$HOME" == /* && -d "$HOME" ]] || exit 1
home_dir="$(cd "$HOME" && pwd -P)"
[[ "$home_dir" != / ]] || exit 1
files=(.zshrc .aliases .config/ohmyposh/mrdemonwolf-server.omp.json)

# Preflight every path and reject edits outside the managed Git history.
for relative in "${files[@]}"; do
  source_file="$repo_dir/config/server/$relative"
  [[ -f "$source_file" && ! -L "$source_file" ]] || exit 1
  current="$home_dir"
  IFS=/ read -r -a parts <<< "$relative"
  for part in "${parts[@]}"; do
    current="$current/$part"
    [[ ! -L "$current" ]] || { echo "Refusing symlink: $current" >&2; exit 1; }
    if [[ "$current" != "$home_dir/$relative" ]]; then
      [[ ! -e "$current" || -d "$current" ]] || exit 1
    fi
  done
  target="$home_dir/$relative"
  [[ ! -e "$target" || -f "$target" ]] || exit 1
  if [[ -f "$target" ]] && ! cmp -s "$source_file" "$target"; then
    blob="$(git hash-object "$target")"
    history="$(git -C "$repo_dir" rev-list --objects HEAD -- "config/server/$relative")"
    if ! grep -q "^$blob " <<< "$history"; then
      echo "Local edits in $target; review them before updating. Move host-only shell additions to .zshrc.local or .aliases.local." >&2
      exit 1
    fi
  fi
done

backup_dir=''
temporary_file=''
trap '[[ -z "$temporary_file" ]] || rm -f "$temporary_file"' EXIT
for relative in "${files[@]}"; do
  source_file="$repo_dir/config/server/$relative"
  target="$home_dir/$relative"
  if [[ -f "$target" ]] && cmp -s "$source_file" "$target"; then
    echo "unchanged $relative"
    continue
  fi
  if [[ "$dry_run" == true ]]; then
    echo "would apply $relative"
    continue
  fi
  if [[ -f "$target" ]]; then
    if [[ -z "$backup_dir" ]]; then
      backup_dir="$(mktemp -d "$home_dir/.server-dotfiles-backup.XXXXXX")"
      echo "Backup: $backup_dir"
    fi
    mkdir -p "$backup_dir/$(dirname "$relative")"
    cp -p "$target" "$backup_dir/$relative"
  fi
  mkdir -p "$(dirname "$target")"
  temporary_file="$(mktemp "$target.tmp.XXXXXX")"
  cp "$source_file" "$temporary_file"
  chmod 644 "$temporary_file"
  mv -f "$temporary_file" "$target"
  temporary_file=''
  echo "applied $relative"
done
if [[ "$dry_run" == true ]]; then
  echo 'No files changed. Dry run uses the current checkout without fetching.'
else
  echo 'Server shell files applied. Reconnect to load them.'
fi
