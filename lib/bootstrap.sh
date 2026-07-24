#!/bin/bash
# Shared bootstrap helpers, sourced by server.sh and server-dev.sh.
# No `set -e` here — callers own their own error handling.

log()     { echo "==> $*"; }
substep() { echo "    $*"; }

# Sets global OS to the kernel name (Darwin / Linux).
detect_os() { OS="$(uname -s)"; }

# Install base packages. macOS via Homebrew (installed if missing), Linux via apt.
install_base_packages() {
  log "Installing packages..."
  if [[ "$OS" == "Darwin" ]]; then
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
    sudo apt update && sudo apt install -y zsh git curl wget fzf
  fi
}

install_oh_my_zsh() {
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
}

install_zsh_plugins() {
  log "Installing Oh My Zsh plugins..."
  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  git clone https://github.com/Aloxaf/fzf-tab "$custom/plugins/fzf-tab" 2>/dev/null || true
  git clone https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions" 2>/dev/null || true
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting" 2>/dev/null || true
}

install_oh_my_posh() {
  if ! command -v oh-my-posh &>/dev/null; then
    log "Installing Oh My Posh..."
    if [[ "$OS" == "Darwin" ]]; then
      brew install jandedobbeleer/oh-my-posh/oh-my-posh
    else
      curl -s https://ohmyposh.dev/install.sh | bash -s
    fi
  fi
}

# copy_configs <source_dir> — copy every file under source_dir into $HOME,
# preserving relative paths, backing up any existing target first.
copy_configs() {
  local src="$1"
  log "Installing configs from ${src#"$HOME"/}..."
  local file relative target
  # ponytail: find-in-for is fine here — dotfile names never contain spaces.
  for file in $(find "$src" -type f); do
    relative="${file#"$src"/}"
    target="$HOME/$relative"
    if [[ -f "$target" ]]; then
      cp "$target" "$target.backup"
      substep "Backed up $target -> $target.backup"
    fi
    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"
    substep "Installed $target"
  done
}

set_default_shell() {
  if [[ "$SHELL" != *"zsh"* ]]; then
    log "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
  fi
}
