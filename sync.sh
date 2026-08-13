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

# Rewrite this machine's home directory back to a literal $HOME, so a file
# captured on the Mac still works on the Ubuntu boxes.
#
# ponytail: one sed over everything, not a per-file rule. Installers append
# absolute paths — `export PATH="/Users/you/.local/bin:$PATH"` — and committed
# as-is they are dead weight on Linux, where that path does not exist. There is
# no case where the literal home prefix is the thing we wanted to record.
# The character class keeps the rewrite off a path that merely starts with the
# home string — /Users/you-old stays put, /Users/you" and /Users/you/bin do not.
portable_filter() {
  sed -e "s|${HOME}\([^A-Za-z0-9_.-]\)|\$HOME\1|g" \
      -e "s|${HOME}\$|\$HOME|g"
}

sync_file() { # source destination [strip_pattern]
  local source=$1 destination=$2 pattern=${3:-}
  mkdir -p "$(dirname "$destination")"
  if [ -n "$pattern" ]; then
    grep -v -E "$pattern" "$source" | portable_filter > "$destination"
  else
    portable_filter < "$source" > "$destination"
  fi
  # Filtering writes a fresh file, so the mode does not come along the way it
  # would with cp. Git tracks the executable bit and install.sh copies it back
  # out, so losing it here would ship ~/.scripts/* unrunnable.
  [ -x "$source" ] && chmod +x "$destination"
  return 0
}

for file in "${files[@]}"; do
  if [ -f "$HOME/$file" ]; then
    strip_pattern="$(strip_pattern_for "$file")"
    sync_file "$HOME/$file" "$CONFIG_DIR/$file" "$strip_pattern"
    if [ -n "$strip_pattern" ]; then
      echo "Synced $file (filtered)"
    else
      echo "Synced $file"
    fi
  fi
done

echo "Skipped .gitconfig and .npmrc; review them manually before committing to this public repo"

# Nested config files
omp_theme="$HOME/.config/ohmyposh/mrdemonwolf.omp.json"
[ -f "$omp_theme" ] && sync_file "$omp_theme" "$CONFIG_DIR/.config/ohmyposh/mrdemonwolf.omp.json"

ghostty_config="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
[ -f "$ghostty_config" ] && sync_file "$ghostty_config" "$CONFIG_DIR/.config/ghostty/config"

# Custom scripts. These are shell scripts, so they carry the same absolute-path
# hazard as the dotfiles and go through the same filter.
if [ -d "$HOME/.scripts" ]; then
  for script in "$HOME/.scripts/"*; do
    [ -f "$script" ] && sync_file "$script" "$CONFIG_DIR/.scripts/$(basename "$script")"
  done
  echo "Synced .scripts/"
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
