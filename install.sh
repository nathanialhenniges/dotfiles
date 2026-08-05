#!/bin/bash
# Install dotfiles onto a new machine
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"
OS="$(uname -s)"

die() {
  echo "error: $*" >&2
  exit 1
}

apply_macos_dotfiles() (
  set -euo pipefail

  local dry_run="$1"
  local home_dir target source relative mode current index last_index temporary_file
  local changed=0
  local -a parts
  local -a mappings=(
    ".zshrc:.zshrc:644"
    ".zprofile:.zprofile:644"
    ".p10k.zsh:.p10k.zsh:644"
    ".profile:.profile:644"
    ".aliases:.aliases:644"
    ".nuxtrc:.nuxtrc:644"
    ".config/ohmyposh/mrdemonwolf.omp.json:.config/ohmyposh/mrdemonwolf.omp.json:644"
    ".config/ghostty/config:Library/Application Support/com.mitchellh.ghostty/config:644"
    ".scripts/new-video:.scripts/new-video:755"
    ".scripts/obs-backup:.scripts/obs-backup:755"
    ".scripts/yt-video-backup:.scripts/yt-video-backup:755"
  )

  mode_of() {
    stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
  }

  [[ "$OS" == "Darwin" ]] || die "--apply-only supports macOS only; use linux-desktop.sh on Ubuntu"
  [[ "$(id -u)" -ne 0 ]] || die "run this as your normal macOS user, never as root"
  [[ -n "${HOME:-}" && "$HOME" == /* && "$HOME" != "/" && -d "$HOME" ]] || die "HOME must be a safe existing absolute path"
  home_dir="$(cd "$HOME" && pwd -P)"

  # Preflight every mapping before writing the first file.
  for mapping in "${mappings[@]}"; do
    IFS=: read -r source relative mode <<< "$mapping"
    source="$CONFIG_DIR/$source"
    [[ -f "$source" && ! -L "$source" ]] || die "missing or unsafe managed source: $source"
    [[ -n "$relative" && "$relative" != /* ]] || die "unsafe destination: $relative"
    case "/$relative/" in
      *"/../"*|*"/./"*) die "unsafe destination: $relative" ;;
    esac

    IFS=/ read -r -a parts <<< "$relative"
    current="$home_dir"
    last_index=$((${#parts[@]} - 1))
    for ((index = 0; index < last_index; index++)); do
      current="$current/${parts[$index]}"
      [[ ! -L "$current" ]] || die "destination path crosses a symbolic link: $current"
      [[ ! -e "$current" || -d "$current" ]] || die "destination parent is not a directory: $current"
    done

    target="$home_dir/$relative"
    [[ ! -L "$target" ]] || die "refusing symbolic-link destination: $target"
    [[ ! -e "$target" || -f "$target" ]] || die "destination is not a regular file: $target"
    [[ ! -L "$target.backup" ]] || die "refusing symbolic-link backup: $target.backup"
    [[ ! -e "$target.backup" || -f "$target.backup" ]] || die "backup is not a regular file: $target.backup"
  done

  for mapping in "${mappings[@]}"; do
    IFS=: read -r source relative mode <<< "$mapping"
    source="$CONFIG_DIR/$source"
    target="$home_dir/$relative"

    if [[ -f "$target" ]] && cmp -s "$source" "$target" && [[ "$(mode_of "$target")" == "$mode" ]]; then
      echo "Already current $target"
      continue
    fi

    if [[ "$dry_run" == "true" ]]; then
      echo "Would apply $target"
      continue
    fi

    if [[ -f "$target" ]]; then
      if [[ -e "$target.backup" ]]; then
        echo "Kept existing $target.backup (original preserved)"
      else
        cp -p "$target" "$target.backup"
        echo "Backed up $target -> $target.backup"
      fi
    fi

    mkdir -p "$(dirname "$target")"
    temporary_file="$(mktemp "${target}.tmp.XXXXXX")"
    cp "$source" "$temporary_file"
    chmod "$mode" "$temporary_file"
    mv -f "$temporary_file" "$target"
    echo "Applied $target"
    changed=$((changed + 1))
  done

  if [[ "$dry_run" == "true" ]]; then
    echo "Dry run complete. No files changed."
  elif ((changed == 0)); then
    echo "macOS dotfiles are already current."
  else
    echo "Applied $changed macOS dotfile(s). Restart your terminal to verify them."
  fi
)

apply_only=false
dry_run=false
for argument in "$@"; do
  case "$argument" in
    --apply-only) apply_only=true ;;
    --dry-run) dry_run=true ;;
    -h|--help)
      echo "Usage: ./install.sh [--apply-only [--dry-run]]"
      exit 0
      ;;
    *) die "unknown option: $argument" ;;
  esac
done

if [[ "$dry_run" == "true" && "$apply_only" != "true" ]]; then
  die "--dry-run is available only with --apply-only"
fi
if [[ "$apply_only" == "true" ]]; then
  apply_macos_dotfiles "$dry_run"
  exit $?
fi

# Install platform-specific packages
if [[ "$OS" == "Darwin" ]]; then
  # macOS: Install Homebrew if missing
  if ! command -v brew &>/dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Apple Silicon at /opt/homebrew, Intel at /usr/local
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  # Install packages from Brewfile
  brew bundle --file="$DOTFILES_DIR/Brewfile"
else
  # Linux/Codespaces: Install essentials via apt
  sudo apt update && sudo apt install -y zsh git curl wget fzf
fi

# Install Oh My Zsh if missing
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Install Oh My Zsh plugins
git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-tab 2>/dev/null
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions 2>/dev/null
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 2>/dev/null

# Copy dotfiles (with backup of existing files)
for file in $(find "$CONFIG_DIR" -type f -not -path "$CONFIG_DIR/server/*"); do
  relative="${file#$CONFIG_DIR/}"

  # Ghostty stores config in Application Support on macOS
  if [[ "$relative" == ".config/ghostty/"* && "$OS" == "Darwin" ]]; then
    target="$HOME/Library/Application Support/com.mitchellh.ghostty/${relative#.config/ghostty/}"
  else
    target="$HOME/$relative"
  fi

  # Never overwrite an existing .backup — a second run would otherwise copy the
  # dotfiles-managed file over the pristine pre-dotfiles original, destroying
  # the only record of what was on the machine before.
  if [ -f "$target" ]; then
    if [ -e "$target.backup" ]; then
      echo "Kept existing $target.backup (original preserved)"
    else
      cp "$target" "$target.backup"
      echo "Backed up $target → $target.backup"
    fi
  fi
  mkdir -p "$(dirname "$target")"
  cp "$file" "$target"
  echo "Installed $target"
done

# Make scripts executable
if [ -d "$HOME/.scripts" ]; then
  chmod +x "$HOME/.scripts/"*
  echo "Made ~/.scripts/* executable"
fi

# Load Homebrew paths so fnm is available
source ~/.zprofile 2>/dev/null

# Install latest Node.js via fnm and set as default
if command -v fnm &>/dev/null; then
  fnm install --latest
  fnm default "$(fnm ls | head -1 | awk '{print $2}')"
  echo "Node.js $(node --version) installed and set as default via fnm"
fi

echo "Done! Restart your terminal to apply changes."
