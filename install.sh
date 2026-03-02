#!/bin/bash
# Install dotfiles onto a new machine
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"
OS="$(uname -s)"

# Install platform-specific packages
if [[ "$OS" == "Darwin" ]]; then
  # macOS: Install Homebrew if missing
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Apple Silicon at /opt/homebrew, Intel at /usr/local
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  # Install packages from Brewfile
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  # Linux/Codespaces: Install essentials via apt
  sudo apt update && sudo apt install -y zsh git curl wget fzf
fi

# Copy dotfiles (with backup of existing files)
for file in $(find "$CONFIG_DIR" -type f); do
  relative="${file#$CONFIG_DIR/}"

  # Ghostty stores config in Application Support on macOS
  if [[ "$relative" == ".config/ghostty/"* && "$OS" == "Darwin" ]]; then
    target="$HOME/Library/Application Support/com.mitchellh.ghostty/${relative#.config/ghostty/}"
  else
    target="$HOME/$relative"
  fi

  if [ -f "$target" ]; then
    cp "$target" "$target.backup"
    echo "Backed up $target → $target.backup"
  fi
  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
  echo "Installed $target"
done

echo "Done! Restart your terminal to apply changes."
