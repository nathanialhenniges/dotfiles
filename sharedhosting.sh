#!/bin/bash
# Bootstrap a shared hosting environment with a clean bash setup (no root required)
# Usage: curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/sharedhosting.sh | bash
set -e

main() {
  REPO_URL="https://github.com/nathanialhenniges/dotfiles.git"
  DOTFILES_DIR="$HOME/dotfiles"

  echo "==> Shared hosting bootstrap starting..."
  echo "    (no root required — everything installs to your home directory)"

  # Clone dotfiles repo (skip if already exists)
  if [[ -d "$DOTFILES_DIR" ]]; then
    echo "==> Dotfiles repo already exists, pulling latest..."
    git -C "$DOTFILES_DIR" pull </dev/null
  else
    echo "==> Cloning dotfiles repo..."
    git clone "$REPO_URL" "$DOTFILES_DIR" </dev/null
  fi

  # Ensure ~/.local/bin exists
  mkdir -p "$HOME/.local/bin"

  # Install Oh My Posh to ~/.local/bin (no root needed)
  if ! command -v oh-my-posh &>/dev/null && [[ ! -x "$HOME/.local/bin/oh-my-posh" ]]; then
    echo "==> Installing Oh My Posh to ~/.local/bin..."
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" || {
      echo "    Warning: Oh My Posh install failed — prompt will use fallback"
    }
  fi

  # Install fzf to ~/.fzf (no root needed)
  if ! command -v fzf &>/dev/null && [[ ! -d "$HOME/.fzf" ]]; then
    echo "==> Installing fzf to ~/.fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" </dev/null && \
      "$HOME/.fzf/install" --bin --no-key-bindings --no-completion --no-update-rc || {
      echo "    Warning: fzf install failed — fuzzy search will be unavailable"
    }
  fi

  # Copy shared hosting configs to home directory (backup existing files first)
  echo "==> Installing shared hosting configs..."
  SH_CONFIG="$DOTFILES_DIR/config/sharedhosting"

  for file in $(find "$SH_CONFIG" -type f); do
    relative="${file#$SH_CONFIG/}"
    target="$HOME/$relative"

    if [[ -f "$target" ]]; then
      cp "$target" "$target.backup"
      echo "    Backed up $target -> $target.backup"
    fi

    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"
    echo "    Installed $target"
  done

  echo ""
  echo "==> Done! Start a new shell session or run: source ~/.bashrc"
}

# Wrap in main() so curl|bash doesn't lose lines when commands read stdin
main
