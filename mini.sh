#!/usr/bin/env bash
# mini.sh — Minimal Mac Mini setup: dotfiles + Oh My Zsh + Oh My Posh
set -e

REPO="https://github.com/nathanialhenniges/dotfiles"
DOTFILES="$HOME/.dotfiles"

echo "→ Cloning dotfiles..."
if [[ -d "$DOTFILES" ]]; then
  git -C "$DOTFILES" pull
else
  git clone "$REPO" "$DOTFILES"
fi

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

echo "→ Patching .zshrc to guard missing tools..."
python3 - << 'PYEOF'
import os
path = os.path.expanduser("~/.zshrc")
c = open(path).read()

# Prepend Ghostty TERM fix if not already present
term_fix = '[[ "$TERM" == "xterm-ghostty" ]] && export TERM="xterm-256color"\n'
if term_fix.strip() not in c:
    c = term_fix + c

fixes = [
    ('eval "$(fnm env', 'command -v fnm &>/dev/null && eval "$(fnm env'),
    ('eval "$(gh completion', 'command -v gh &>/dev/null && eval "$(gh completion'),
    ('eval "$(oh-my-posh', 'command -v oh-my-posh &>/dev/null && eval "$(oh-my-posh'),
    ('source <(fzf --zsh)', 'command -v fzf &>/dev/null && source <(fzf --zsh)'),
    ('eval "$(direnv hook', 'command -v direnv &>/dev/null && eval "$(direnv hook'),
]
for old, new in fixes:
    c = c.replace(old, new)
open(path, 'w').write(c)
print("  .zshrc patched")
PYEOF

echo "→ Installing Oh My Posh..."
curl -s https://ohmyposh.dev/install.sh | bash -s

echo ""
echo "✓ Done! Run: exec zsh"
