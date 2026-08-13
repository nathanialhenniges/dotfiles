#!/bin/bash
# Shared bootstrap helpers, sourced by server.sh and server-dev.sh.
# No `set -e` here — callers own their own error handling.

log()     { echo "==> $*"; }
substep() { echo "    $*"; }

# Sets global OS to the kernel name (Darwin / Linux).
detect_os() { OS="$(uname -s)"; }

# Managed dotfiles as `repo_path:home_path`, one per line.
#
# These mirror the mapping tables inside install.sh (macOS) and
# linux-desktop.sh (Linux), which own the apply direction. sync.sh reads them
# for the capture direction, so the two stay exact inverses: a file the
# installer writes is a file sync reads back, and nothing else is captured.
#
# ponytail: the data lives in one place, not three. The apply tables cannot be
# shared outright without editing two security-hardened scripts, so
# tests/test_sync_mappings.sh fails if these ever drift from the real ones.
#
# .gitconfig and .npmrc are deliberately absent. Neither installer applies them,
# and sync must not push a personal identity file to a public repo.
macos_mappings() {
  cat <<'EOF'
config/.zshrc:.zshrc
config/.zprofile:.zprofile
config/.p10k.zsh:.p10k.zsh
config/.profile:.profile
config/.aliases:.aliases
config/.nuxtrc:.nuxtrc
config/.config/ohmyposh/mrdemonwolf.omp.json:.config/ohmyposh/mrdemonwolf.omp.json
config/.config/ghostty/config:Library/Application Support/com.mitchellh.ghostty/config
config/.scripts/new-video:.scripts/new-video
config/.scripts/obs-backup:.scripts/obs-backup
config/.scripts/yt-video-backup:.scripts/yt-video-backup
EOF
}

linux_mappings() {
  cat <<'EOF'
profiles/linux-desktop/.zshrc:.zshrc
profiles/linux-desktop/.aliases:.aliases
profiles/linux-desktop/.config/ghostty/config:.config/ghostty/config
config/.config/ohmyposh/mrdemonwolf.omp.json:.config/ohmyposh/mrdemonwolf.omp.json
EOF
}

# mappings_for_os [PROFILE]
#
# Echoes the mapping table for the running OS. Linux needs PROFILE spelled out,
# because two very different kinds of Linux box read this repo: the desktop
# profile above, and the server/devbox profile that server-dev.sh applies from
# config/server as a whole directory.
#
# ponytail: an explicit flag, not a heuristic. Guessing "desktop or server?"
# from the environment is the kind of check that is right until the day it is
# not, and being wrong here means capturing a devbox's shell config over the
# desktop profile — a mess to unpick from a diff you were not expecting.
# config/server is applied wholesale by server.sh and is not captured at all.
mappings_for_os() {
  local profile="${1:-}"
  case "$(uname -s)" in
    Darwin) macos_mappings ;;
    Linux)
      case "$profile" in
        linux-desktop) linux_mappings ;;
        '')
          echo "error: on Linux, name the profile: sync.sh --profile linux-desktop" >&2
          echo "       (server and devbox configs are applied by server-dev.sh, not captured)" >&2
          return 1
          ;;
        *) echo "error: unknown profile: $profile" >&2; return 1 ;;
      esac
      ;;
    *) echo "error: unsupported platform: $(uname -s)" >&2; return 1 ;;
  esac
}

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
