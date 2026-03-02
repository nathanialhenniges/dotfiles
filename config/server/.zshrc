# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

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
# Shell Configuration
# =============================================================================

# ── GPG (commit signing) ───────────────────────────────────
export GPG_TTY=$(tty)

# ── fzf keybindings (Ctrl+R for fuzzy history search) ──────
source <(fzf --zsh)

# ── fzf-tab configuration ──────────────────────────────────
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':fzf-tab:*' fzf-flags --bind=tab:accept

# ── History search with arrow keys ─────────────────────────
bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

# ── Secrets (API tokens, etc.) ─────────────────────────────
[[ -f ~/.secrets ]] && source ~/.secrets
