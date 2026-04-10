#!/usr/bin/env bash
# mini.sh — Mac Mini setup: dotfiles + Oh My Zsh + core packages
set -e

REPO="https://github.com/nathanialhenniges/dotfiles"
DOTFILES="$HOME/.dotfiles"

echo "→ Cloning dotfiles..."
if [[ -d "$DOTFILES" ]]; then
  git -C "$DOTFILES" pull
else
  git clone "$REPO" "$DOTFILES"
fi

echo "→ Installing Homebrew..."
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Load brew into current session
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "→ Installing packages..."
brew install fnm fzf direnv gh oh-my-posh

echo "→ Installing Oh My Zsh..."
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

echo "→ Installing Oh My Zsh plugins..."
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 2>/dev/null || true

echo "→ Copying dotfiles..."
find "$DOTFILES/config" -type f \
  ! -path "*/server/*" \
  ! -path "*/sharedhosting/*" \
  ! -path "*/.config/ghostty/*" | while read -r file; do
  relative="${file#$DOTFILES/config/}"
  target="$HOME/$relative"
  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
done

echo "→ Adding Ghostty TERM fix to .zshrc..."
python3 - << 'PYEOF'
import os
path = os.path.expanduser("~/.zshrc")
c = open(path).read()
term_fix = '[[ "$TERM" == "xterm-ghostty" ]] && export TERM="xterm-256color"\n'
if term_fix.strip() not in c:
    c = term_fix + c
open(path, 'w').write(c)
print("  Done")
PYEOF

echo ""
echo "✓ Done! Run: exec zsh"
