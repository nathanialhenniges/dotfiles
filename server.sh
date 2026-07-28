#!/bin/bash
# Bootstrap a remote server (macOS or Linux) with a clean zsh environment
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/nathanialhenniges/dotfiles/main/server.sh)
#
# pipefail so a failed download in a `curl ... | bash` step is not masked by the
# exit status of the shell that then runs nothing. `set -e` alone reports only
# the last command in a pipeline.
set -e
set -o pipefail

REPO_URL="https://github.com/nathanialhenniges/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

echo "==> Server bootstrap starting..."

# Clone dotfiles repo (skip if already exists) — must happen before we can
# source the shared bootstrap lib below.
if [[ -d "$DOTFILES_DIR" ]]; then
  echo "==> Dotfiles repo already exists, pulling latest..."
  git -C "$DOTFILES_DIR" pull
else
  echo "==> Cloning dotfiles repo..."
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi

# shellcheck source=lib/bootstrap.sh
source "$DOTFILES_DIR/lib/bootstrap.sh"

detect_os
install_base_packages
install_oh_my_zsh
install_zsh_plugins
install_oh_my_posh
copy_configs "$DOTFILES_DIR/config/server"
set_default_shell

echo ""
echo "==> Done! Reconnect your SSH session to start using zsh."
