#!/bin/bash
# Sync dotfiles from system into this repo
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"

files=(
  ".zshrc"
  ".zprofile"
  ".p10k.zsh"
  ".profile"
  ".aliases"
  ".gitconfig"
  ".npmrc"
  ".nuxtrc"
)

# Lines that must never be committed, matched per-file. Nuxt writes a
# machine-specific telemetry.seed into ~/.nuxtrc on first run; without this
# filter it comes straight back on the next sync after being removed.
declare -A strip_patterns=(
  [".nuxtrc"]='^telemetry\.seed='
)

for file in "${files[@]}"; do
  if [ -f "$HOME/$file" ]; then
    if [[ -n "${strip_patterns[$file]:-}" ]]; then
      grep -v -E "${strip_patterns[$file]}" "$HOME/$file" > "$CONFIG_DIR/$file"
      echo "Synced $file (filtered)"
    else
      cp "$HOME/$file" "$CONFIG_DIR/$file"
      echo "Synced $file"
    fi
  fi
done

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

# Regenerate Brewfile
brew bundle dump --force --file="$DOTFILES_DIR/Brewfile"
echo "Brewfile updated"

echo "Done! Review changes with: git diff"
