#!/bin/bash
# Shared bootstrap helpers, sourced by server.sh and server-dev.sh.
# No `set -e` here — callers own their own error handling.

log()     { echo "==> $*"; }
substep() { echo "    $*"; }

# Sets global OS to the kernel name (Darwin / Linux).
detect_os() { OS="$(uname -s)"; }

# merge_brewfile EXISTING DUMP OUT
#
# Union a `brew bundle dump` into an existing Brewfile. Entries are only ever
# added — anything already recorded survives even when this machine no longer
# has it installed.
#
# ponytail: the obvious version is `brew bundle dump --force` straight over the
# Brewfile, and it quietly deletes. The repo describes every machine; the dump
# describes the one you happen to be sitting at. Run it on a Mac that never had
# Raycast and Raycast is gone from the rebuild list forever, with nothing in the
# diff to explain why. To drop an entry, edit the Brewfile by hand.
merge_brewfile() {
  local existing=$1 dump=$2 out=$3
  local keys grouped entry key kind

  # Key = the entry minus its trailing options, so `tap "x"` and
  # `tap "x", trusted: true` are one entry and the recorded form wins.
  keys="$(mktemp)"
  sed -E 's/^([a-z]+ "[^"]*").*/\1/' "$existing" | grep -E '^[a-z]+ "' > "$keys"

  cp "$existing" "$out"
  while IFS= read -r entry; do
    case "$entry" in ''|'#'*) continue ;; esac
    key="$(printf '%s\n' "$entry" | sed -E 's/^([a-z]+ "[^"]*").*/\1/')"
    grep -Fxq "$key" "$keys" && continue
    printf '%s\n' "$entry" >> "$out"
    printf '%s\n' "$key" >> "$keys"
  done < "$dump"
  rm -f "$keys"

  # Regroup so an added line lands with its own kind instead of at the bottom,
  # where it would churn every later diff. Anything that is not one of the five
  # known kinds is preserved verbatim at the end rather than dropped.
  grouped="$(mktemp)"
  for kind in tap brew cask mas npm vscode; do
    { grep -E "^${kind} " "$out" || true; } | sort -u
  done > "$grouped"
  { grep -vE '^(tap|brew|cask|mas|npm|vscode) |^[[:space:]]*$' "$out" || true; } >> "$grouped"
  mv -f "$grouped" "$out"
}

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
    sudo apt update && sudo apt install -y zsh git curl wget fzf unzip
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
    # Never overwrite an existing .backup. The copy was unconditional, so the
    # SECOND run backed up the dotfiles-managed file over the pristine
    # pre-dotfiles original — silently destroying the only copy of whatever was
    # on the box before, at the exact moment you were most likely to want it.
    # A backup that only survives until the next run is not a backup.
    if [[ -f "$target" ]]; then
      if [[ -e "$target.backup" ]]; then
        substep "Kept existing $target.backup (original preserved)"
      else
        cp "$target" "$target.backup"
        substep "Backed up $target -> $target.backup"
      fi
    fi
    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"
    substep "Installed $target"
  done
}

set_default_shell() {
  if [[ "$SHELL" != *"zsh"* ]]; then
    log "Changing default shell to zsh..."
    local zsh_path
    zsh_path="$(command -v zsh)"
    # Unprivileged chsh authenticates the caller through PAM, which fails for a
    # cloud account created with --disabled-password. That is the normal state
    # of a freshly provisioned server user, so the plain call always loses
    # there. sudo chsh edits /etc/passwd directly and does not prompt.
    chsh -s "$zsh_path" 2>/dev/null || sudo chsh -s "$zsh_path" "$(id -un)"
  fi
}
