#!/bin/bash
# Install dotfiles onto a new machine
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install packages from Brewfile
brew bundle --file="$DOTFILES_DIR/Brewfile"

# Copy dotfiles (with backup of existing files)
for file in $(find "$CONFIG_DIR" -type f); do
  target="$HOME/${file#$CONFIG_DIR/}"
  if [ -f "$target" ]; then
    cp "$target" "$target.backup"
    echo "Backed up $target → $target.backup"
  fi
  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
  echo "Installed $target"
done

echo "Done! Restart your terminal to apply changes."
