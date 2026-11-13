#!/usr/bin/env bash
# Clone owned, accessible GitHub repositories; existing paths are never updated.
set -euo pipefail

dry_run=0
case "${1:-}" in
  --dry-run) dry_run=1 ;;
  -h|--help)
    echo 'Usage: bash scripts/clone-dev-repos.sh [--dry-run]'
    echo 'Clone accessible repos from MrDemonWolf, nathanialhenniges, and kommitai into ~/Developer/<owner>/<repo>.'
    echo 'Set DEV_REPOS_ROOT to an existing absolute directory to use another drive.'
    echo 'Or save that path in ~/.config/dotfiles/dev-repos-root for this machine.'
    exit 0 ;;
  '') ;;
  *) echo "Unknown option: $1" >&2; exit 1 ;;
esac
[[ $# -le 1 ]] || { echo 'Expected at most --dry-run' >&2; exit 1; }
for tool in gh git; do
  command -v "$tool" >/dev/null || { echo "Missing $tool; install it first." >&2; exit 1; }
done

configured_root="${DEV_REPOS_ROOT:-}"
root_config="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/dev-repos-root"
if [[ -z "$configured_root" && ( -e "$root_config" || -L "$root_config" ) ]]; then
  [[ -f "$root_config" && ! -L "$root_config" ]] || { echo 'Unsafe developer root config' >&2; exit 1; }
  configured_root="$(cat "$root_config")"
  [[ -n "$configured_root" ]] || { echo 'Developer root config is empty' >&2; exit 1; }
fi
root="${configured_root:-$HOME/Developer}"
[[ "$root" == /* && "$root" != / ]] || { echo 'Developer root must be an absolute directory other than /' >&2; exit 1; }
[[ ! -L "$root" ]] || { echo "Refusing symlink: $root" >&2; exit 1; }
if [[ -n "$configured_root" && ! -d "$root" ]]; then
  echo "Configured developer root is missing (external drive unmounted?): $root" >&2
  exit 1
fi
query='query($owner: String!, $endCursor: String) {
  repositoryOwner(login: $owner) {
    repositories(first: 100, after: $endCursor, ownerAffiliations: [OWNER], orderBy: {field: NAME, direction: ASC}) {
      nodes { nameWithOwner }
      pageInfo { hasNextPage endCursor }
    }
  }
}'
cloned=0; skipped=0; planned=0; failed=0
for owner in MrDemonWolf nathanialhenniges kommitai; do
  owner_dir=$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')
  if [[ -L "$root/$owner_dir" ]]; then
    echo "Refusing symlink: $root/$owner_dir" >&2
    failed=$((failed + 1)); continue
  fi
  # Finish all API pages before cloning this owner, so partial listings cannot look complete.
  if ! repos=$(gh api --hostname github.com graphql --paginate -F owner="$owner" \
    -f query="$query" --jq '.data.repositoryOwner.repositories.nodes[].nameWithOwner'); then
    echo "Could not list $owner. Check gh auth login and organization access." >&2
    failed=$((failed + 1)); continue
  fi
  while IFS= read -r repo; do
    [[ -n "$repo" ]] || continue
    repo_owner=$(printf '%s' "${repo%%/*}" | tr '[:upper:]' '[:lower:]')
    name="${repo#*/}"
    if [[ "$repo" != */* || "$repo_owner" != "$owner_dir" || ! "$name" =~ ^[A-Za-z0-9_.-]+$ || "$name" == . || "$name" == .. ]]; then
      echo "Invalid repository path from GitHub: $repo" >&2
      failed=$((failed + 1)); continue
    fi
    destination="$root/$owner_dir/$name"
    if [[ -e "$destination" || -L "$destination" ]]; then
      echo "Skip existing: $destination"
      skipped=$((skipped + 1))
    elif [[ "$dry_run" -eq 1 ]]; then
      echo "Would clone: $repo -> $destination"
      planned=$((planned + 1))
    else
      mkdir -p "$root/$owner_dir"
      if GH_HOST=github.com gh repo clone "$repo" "$destination"; then
        cloned=$((cloned + 1))
      else
        echo "Clone failed: $repo (existing data left alone)" >&2
        failed=$((failed + 1))
      fi
    fi
  done <<< "$repos"
done
printf 'Cloned: %s | Existing: %s | Would clone: %s | Failures: %s\n' "$cloned" "$skipped" "$planned" "$failed"
[[ "$failed" -eq 0 ]]
