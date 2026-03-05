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

# Add Ghostty terminal fix and .bashrc source to all login shell configs
GHOSTTY_FIX='[ "$TERM" = "xterm-ghostty" ] && export TERM="xterm-256color"'
BASHRC_SOURCE='[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"'

for rcfile in "$HOME/.bash_profile" "$HOME/.profile"; do
  if [ -f "$rcfile" ]; then
    if ! grep -q 'xterm-ghostty' "$rcfile" 2>/dev/null; then
      # Prepend the fix so it runs before anything else
      printf '%s\n%s' "$GHOSTTY_FIX" "$(cat "$rcfile")" > "$rcfile"
      echo "    Added Ghostty fix to $rcfile"
    fi
    if ! grep -q '\.bashrc' "$rcfile" 2>/dev/null; then
      echo "$BASHRC_SOURCE" >> "$rcfile"
      echo "    Added .bashrc source to $rcfile"
    fi
  else
    printf '%s\n%s\n' "$GHOSTTY_FIX" "$BASHRC_SOURCE" > "$rcfile"
    echo "    Created $rcfile"
  fi
done

echo ""
echo "==> Done! Start a new shell session or run: source ~/.bashrc"
