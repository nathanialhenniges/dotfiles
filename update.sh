#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
dry_run=false
profile=""

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry_run=true; shift ;;
    --profile) profile="${2:-}"; shift 2 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./update.sh [--profile linux-desktop] [--dry-run]

Fast-forward this trusted dotfiles checkout, then apply the current
platform's desktop profile. This never commits or pushes changes.

macOS needs no flag. Linux requires --profile, because the server and
devbox configs are applied by server-dev.sh and must not be overwritten
with the desktop profile.
EOF
      exit 0
      ;;
    *) die "unknown option: $1" ;;
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

# Linux has to say which profile it wants. Two very different kinds of Linux box
# read this repo: a desktop, and the server/devbox that server-dev.sh provisions
# from config/server. A bare run used to assume desktop and overwrite a devbox's
# shell config with 100+ lines of the wrong profile — mrdemonwolf-dev and
# kommit-dev were both one keystroke away from it.
#
# ponytail: the same explicit flag sync.sh already requires, not a new heuristic.
# Detecting "is this a desktop?" is a guess that is right until it is not, and
# the two scripts disagreeing about the answer is worse than either answer.
platform="$(uname -s)"
case "$platform" in
  Darwin) apply_command=("$repo_dir/install.sh" --apply-only) ;;
  Linux)
    case "$profile" in
      linux-desktop) apply_command=("$repo_dir/linux-desktop.sh") ;;
      '')
        printf 'error: on Linux, name the profile: ./update.sh --profile linux-desktop\n' >&2
        printf '       (server and devbox configs are applied by server-dev.sh, not this)\n' >&2
        exit 1
        ;;
      *) die "unknown profile: $profile" ;;
    esac
    ;;
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
