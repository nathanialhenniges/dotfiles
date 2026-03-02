#!/bin/bash
# Bootstrap a remote server (macOS or Linux) with a clean zsh environment
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/server.sh)
set -e

REPO_URL="https://github.com/nathanialhenniges/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

echo "==> Server bootstrap starting..."

# Clone dotfiles repo (skip if already exists)
if [[ -d "$DOTFILES_DIR" ]]; then
  echo "==> Dotfiles repo already exists, pulling latest..."
  git -C "$DOTFILES_DIR" pull
else
  echo "==> Cloning dotfiles repo..."
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# Install essentials
echo "==> Installing packages..."
OS="$(uname -s)"
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
  brew install zsh git curl wget fzf
else
  # Linux: Install via apt
  sudo apt update && sudo apt install -y zsh git curl wget fzf
fi

# Install Oh My Zsh (skip if already installed)
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "==> Installing Oh My Zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install Oh My Zsh plugins (skip if already cloned)
echo "==> Installing Oh My Zsh plugins..."
git clone https://github.com/Aloxaf/fzf-tab "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" 2>/dev/null || true

# Copy server configs to home directory (backup existing files first)
echo "==> Installing server configs..."
SERVER_CONFIG="$DOTFILES_DIR/config/server"

for file in $(find "$SERVER_CONFIG" -type f); do
  relative="${file#$SERVER_CONFIG/}"
  target="$HOME/$relative"

  if [[ -f "$target" ]]; then
    cp "$target" "$target.backup"
    echo "    Backed up $target -> $target.backup"
  fi

  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
  echo "    Installed $target"
done

# Change default shell to zsh if currently using bash
if [[ "$SHELL" != *"zsh"* ]]; then
  echo "==> Changing default shell to zsh..."
  chsh -s "$(which zsh)"
fi

echo ""
echo "==> Done! Reconnect your SSH session to start using zsh."
