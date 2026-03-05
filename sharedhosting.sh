#!/bin/sh
# Bootstrap a shared hosting environment (no root, no git, just curl + sh)
# Usage: curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/sharedhosting.sh | sh
set -e

BASE_URL="https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/config/sharedhosting"

echo "==> Shared hosting bootstrap starting..."
echo "    (no root required — everything installs to your home directory)"

# Download .bashrc
if [ -f "$HOME/.bashrc" ]; then
  cp "$HOME/.bashrc" "$HOME/.bashrc.backup"
  echo "    Backed up ~/.bashrc -> ~/.bashrc.backup"
fi
curl -fsSL "$BASE_URL/.bashrc" -o "$HOME/.bashrc"
echo "    Installed ~/.bashrc"

# Download .aliases
if [ -f "$HOME/.aliases" ]; then
  cp "$HOME/.aliases" "$HOME/.aliases.backup"
  echo "    Backed up ~/.aliases -> ~/.aliases.backup"
fi
curl -fsSL "$BASE_URL/.aliases" -o "$HOME/.aliases"
echo "    Installed ~/.aliases"

# Source .bashrc from .bash_profile if not already done (login shells)
if [ -f "$HOME/.bash_profile" ]; then
  if ! grep -q '\.bashrc' "$HOME/.bash_profile" 2>/dev/null; then
    echo '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"' >> "$HOME/.bash_profile"
    echo "    Added .bashrc source to .bash_profile"
  fi
else
  echo '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"' > "$HOME/.bash_profile"
  echo "    Created .bash_profile"
fi

echo ""
echo "==> Done! Start a new shell session or run: source ~/.bashrc"
