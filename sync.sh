#!/bin/bash
# Sync dotfiles from system into this repo
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"

# shellcheck source=lib/bootstrap.sh
source "$DOTFILES_DIR/lib/bootstrap.sh"

files=(
  ".zshrc"
  ".zprofile"
  ".p10k.zsh"
  ".profile"
  ".aliases"
  ".nuxtrc"
)

# Lines that must never be committed, matched per-file. Nuxt writes a
# machine-specific telemetry.seed into ~/.nuxtrc on first run; without this
# filter it comes straight back on the next sync after being removed.
#
# ponytail: a case, not an associative array. macOS still ships bash 3.2, which
# has no `declare -A`, so this whole loop was aborting with a syntax error and
# nothing on the Mac had actually been syncing.
strip_pattern_for() {
  case "$1" in
    .nuxtrc) printf '%s' '^telemetry\.seed=' ;;
  esac
}

for file in "${files[@]}"; do
  if [ -f "$HOME/$file" ]; then
    strip_pattern="$(strip_pattern_for "$file")"
    if [ -n "$strip_pattern" ]; then
      grep -v -E "$strip_pattern" "$HOME/$file" > "$CONFIG_DIR/$file"
      echo "Synced $file (filtered)"
    else
      cp "$HOME/$file" "$CONFIG_DIR/$file"
      echo "Synced $file"
    fi
  fi
done

echo "Skipped .gitconfig and .npmrc; review them manually before committing to this public repo"

# Nested config files
mkdir -p "$CONFIG_DIR/.config/ohmyposh"
cp "$HOME/.config/ohmyposh/mrdemonwolf.omp.json" "$CONFIG_DIR/.config/ohmyposh/" 2>/dev/null

mkdir -p "$CONFIG_DIR/.config/ghostty"
cp "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "$CONFIG_DIR/.config/ghostty/config" 2>/dev/null

# Custom scripts
if [ -d "$HOME/.scripts" ]; then
  mkdir -p "$CONFIG_DIR/.scripts"
  cp "$HOME/.scripts/"* "$CONFIG_DIR/.scripts/" 2>/dev/null && echo "Synced .scripts/"
fi

# Merge current system into the Brewfile.
#
# ponytail: union, never subtract. A plain `brew bundle dump --force` rewrites
# the Brewfile to whatever this one Mac happens to have right now, so anything
# installed on another machine — or temporarily uninstalled here — silently
# disappears from the repo and never gets reinstalled on a rebuild. Entries are
# only ever added. Remove one by editing the Brewfile by hand.
brewfile="$DOTFILES_DIR/Brewfile"
dump="$(mktemp)"
merged="$(mktemp)"
trap 'rm -f "$dump" "$merged"' EXIT

brew bundle dump --force --file="$dump"
merge_brewfile "$brewfile" "$dump" "$merged"
added=$(comm -13 <(sort "$brewfile") <(sort "$merged") | wc -l | tr -d ' ')
mv -f "$merged" "$brewfile"
echo "Brewfile merged ($added added, 0 removed)"

echo "Done! Review changes with: git diff"
