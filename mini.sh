#!/bin/bash
# mini.sh — Minimal dotfiles bootstrap (zsh + oh-my-posh, no full Brewfile)
REPO="https://github.com/nathanialhenniges/dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"

# Clone or update dotfiles repo
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  echo "→ Updating dotfiles..."
  git -C "$DOTFILES_DIR" pull
else
  echo "→ Cloning dotfiles..."
  git clone "$REPO" "$DOTFILES_DIR"
fi

CONFIG_DIR="$DOTFILES_DIR/config"

# Install Homebrew if missing
if ! command -v brew &>/dev/null; then
  echo "→ Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Load Homebrew into current session
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# Install only what .zshrc needs
echo "→ Installing packages..."
brew install fnm fzf direnv gh jandedobbeleer/oh-my-posh/oh-my-posh

# Install Oh My Zsh if missing
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo "→ Installing Oh My Zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install Oh My Zsh plugins
echo "→ Installing Oh My Zsh plugins..."
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null || true

# Copy dotfiles (with backup of existing files)
echo "→ Copying dotfiles..."
for file in $(find "$CONFIG_DIR" -type f \
  -not -path "$CONFIG_DIR/server/*" \
  -not -path "$CONFIG_DIR/sharedhosting/*" \
  -not -path "$CONFIG_DIR/.config/ghostty/*"); do
  relative="${file#$CONFIG_DIR/}"
  target="$HOME/$relative"

  if [ -f "$target" ]; then
    cp "$target" "$target.backup"
  fi
  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
done

# Prepend Ghostty TERM fix to .zshrc
if ! grep -q 'xterm-ghostty' "$HOME/.zshrc"; then
  echo '→ Adding Ghostty TERM fix...'
  printf '[[ "$TERM" == "xterm-ghostty" ]] && export TERM="xterm-256color"\n' | \
    cat - "$HOME/.zshrc" > /tmp/zshrc_tmp && mv /tmp/zshrc_tmp "$HOME/.zshrc"
fi

# Make scripts executable
if [ -d "$HOME/scripts" ]; then
  chmod +x "$HOME/scripts/"*
fi

# Load updated zprofile so fnm is available
source "$HOME/.zprofile" 2>/dev/null || true

# Install latest Node.js via fnm
if command -v fnm &>/dev/null; then
  echo "→ Installing Node.js via fnm..."
  fnm install --latest
  fnm default "$(fnm ls | head -1 | awk '{print $2}')"
fi

echo ""
echo "✓ Done! Run: exec zsh"
