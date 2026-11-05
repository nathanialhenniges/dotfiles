#!/usr/bin/env bash
set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
theme_dir="$dotfiles_dir/local/orca/monokai-pro-octagon"
repository='nathanialhenniges/orca-monokai-pro'
die() { echo "Orca themes: $*" >&2; exit 1; }

if [[ $# -gt 0 ]]; then
  [[ $# -eq 1 && "$1" == '--dry-run' ]] || die 'usage: bash scripts/install-orca-themes.sh [--dry-run]'
  echo "Would privately clone or fast-forward $repository into $theme_dir, validate, and load it in Orca."
  exit 0
fi

orca_cli="${ORCA_CLI_COMMAND:-}"
if [[ -z "$orca_cli" ]]; then
  if [[ "$(uname -s)" == Darwin ]]; then
    orca_cli='/Applications/Orca.app/Contents/Resources/bin/orca'
  else
    orca_cli='orca-ide'
  fi
fi
command -v "$orca_cli" >/dev/null || die "Orca CLI not found: $orca_cli"
command -v gh >/dev/null || die 'install GitHub CLI and run gh auth login first'
command -v git >/dev/null || die 'install Git first'
[[ "$(gh repo view "$repository" --json visibility --jq .visibility)" == PRIVATE ]] || die 'theme repository must remain PRIVATE'

for path in "$dotfiles_dir/local" "$dotfiles_dir/local/orca" "$theme_dir"; do
  [[ ! -L "$path" ]] || die "refusing symbolic-link path: $path"
done
if [[ -e "$theme_dir" ]]; then
  [[ -d "$theme_dir/.git" && ! -L "$theme_dir/.git" ]] || die "existing folder is not a managed clone: $theme_dir"
  [[ "$(git -C "$theme_dir" remote get-url origin)" == "https://github.com/$repository.git" ]] || die 'unexpected theme repository origin'
  [[ "$(git -C "$theme_dir" branch --show-current)" == main ]] || die 'theme clone must be on main'
  [[ -z "$(git -C "$theme_dir" status --porcelain)" ]] || die 'theme clone has local changes; preserve or commit them before updating'
  git -C "$theme_dir" pull --ff-only
else
  mkdir -p "$(dirname "$theme_dir")"
  gh repo clone "$repository" "$theme_dir" -- --branch main
fi
"$orca_cli" plugin validate "$theme_dir" --json
"$orca_cli" plugin dev load "$theme_dir" --json
echo 'Loaded Monokai themes. Select your app/editor and terminal variants in Orca Settings > Appearance.'
