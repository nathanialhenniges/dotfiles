#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
dry_run=false

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

for argument in "$@"; do
  case "$argument" in
    --dry-run) dry_run=true ;;
    -h|--help)
      cat <<'EOF'
Usage: ./update.sh [--dry-run]

Fast-forward this trusted dotfiles checkout, then apply only the current
platform's desktop profile. This never commits or pushes changes.
EOF
      exit 0
      ;;
    *) die "unknown option: $argument" ;;
  esac
done

[[ "$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null)" == "$repo_dir" ]] || \
  die "update.sh must live at the root of its Git checkout"

origin_url="$(git -C "$repo_dir" config --get remote.origin.url || true)"
case "$origin_url" in
  https://github.com/nathanialhenniges/dotfiles|https://github.com/nathanialhenniges/dotfiles.git|git@github.com:nathanialhenniges/dotfiles.git|ssh://git@github.com/nathanialhenniges/dotfiles.git) ;;
  *) die "origin is not nathanialhenniges/dotfiles: ${origin_url:-missing}" ;;
esac

branch="$(git -C "$repo_dir" branch --show-current)"
[[ "$branch" == "main" ]] || die "checkout must be on main, not ${branch:-detached HEAD}"
[[ -z "$(git -C "$repo_dir" status --porcelain)" ]] || die "worktree is not clean; review or stash local changes first"

platform="$(uname -s)"
case "$platform" in
  Darwin) apply_command=("$repo_dir/install.sh" --apply-only) ;;
  Linux) apply_command=("$repo_dir/linux-desktop.sh") ;;
  *) die "unsupported platform: $platform" ;;
esac

if [[ "$dry_run" == "true" ]]; then
  printf 'Would fetch origin/main and merge it with --ff-only.\n'
  "${apply_command[@]}" --dry-run
  exit 0
fi

git -C "$repo_dir" fetch origin main
git -C "$repo_dir" merge --ff-only origin/main
"${apply_command[@]}"

printf 'Dotfiles updated and applied. No commit or push was made.\n'
