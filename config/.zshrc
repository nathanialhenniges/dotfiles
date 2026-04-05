# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME=""

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(
  git
  fzf-tab
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# =============================================================================
# Custom Aliases
# =============================================================================
[[ -f ~/.aliases ]] && source ~/.aliases

# =============================================================================
# Homebrew PATH & Environment
# =============================================================================

if [[ "$(uname)" == "Darwin" ]]; then
  # ── fnm (Fast Node Manager) ────────────────────────────────
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# ── Go ──────────────────────────────────────────────────────
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

if [[ "$(uname)" == "Darwin" ]]; then
  # ── PHP (Homebrew over system) ──────────────────────────────
  export PATH="$(brew --prefix php)/bin:$PATH"
  export PATH="$(brew --prefix php)/sbin:$PATH"
fi

# ── GPG (commit signing) ───────────────────────────────────
export GPG_TTY=$(tty)

if [[ "$(uname)" == "Darwin" ]]; then
  # ── Terraform autocomplete ──────────────────────────────────
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C "$(brew --prefix)/bin/terraform" terraform

  # ── Google Cloud SDK ────────────────────────────────────────
  if [ -f "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc" ]; then
    source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"
  fi
  if [ -f "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc" ]; then
    source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
  fi

  # ── Java (Zulu JDK 17 for Android) ─────────────────────────
  export JAVA_HOME="/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home"
  export PATH="$JAVA_HOME/bin:$PATH"

  # ── Android Studio / React Native ───────────────────────────
  export ANDROID_HOME="$HOME/Library/Android/sdk"
  export PATH="$ANDROID_HOME/emulator:$PATH"
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
  export PATH="$ANDROID_HOME/tools:$PATH"
  export PATH="$ANDROID_HOME/tools/bin:$PATH"

  # ── GitHub CLI completion ───────────────────────────────────
  eval "$(gh completion -s zsh)"
fi

# =============================================================================
# Prompt & Shell Enhancements
# =============================================================================

if [[ "$(uname)" == "Darwin" ]]; then
  # ── Oh My Posh prompt ──────────────────────────────────────
  eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/mrdemonwolf.omp.json)"
fi

# ── fzf keybindings (Ctrl+R for fuzzy history search) ──────
source <(fzf --zsh)

# ── fzf-tab configuration (Warp-like tab completion) ───────
# Show directory previews when tab-completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# Colorize completions
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# Disable default menu so fzf-tab takes over
zstyle ':completion:*' menu no
# Group completions with descriptions
zstyle ':completion:*:descriptions' format '[%d]'
# Switch groups with , and .
zstyle ':fzf-tab:*' switch-group ',' '.'
# Accept selection with Tab (like Warp)
zstyle ':fzf-tab:*' fzf-flags --bind=tab:accept

# ── History search with arrow keys ─────────────────────────
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

# ── Secrets (API tokens, etc.) ─────────────────────────────
# Store secrets in ~/.secrets (never committed to git)
[[ -f ~/.secrets ]] && source ~/.secrets
eval "$(direnv hook zsh)"
