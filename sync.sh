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

for file in "${files[@]}"; do
  if [ -f "$HOME/$file" ]; then
    cp "$HOME/$file" "$CONFIG_DIR/$file"
    echo "Synced $file"
  fi
done

# Nested config files
mkdir -p "$CONFIG_DIR/.config/ohmyposh"
cp "$HOME/.config/ohmyposh/mrdemonwolf.omp.json" "$CONFIG_DIR/.config/ohmyposh/" 2>/dev/null

# Regenerate Brewfile
brew bundle dump --force --file="$DOTFILES_DIR/Brewfile"
echo "Brewfile updated"

echo "Done! Review changes with: git diff"
