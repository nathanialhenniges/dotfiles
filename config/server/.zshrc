# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

# Oh My Posh prompt
if ! command -v oh-my-posh &>/dev/null && [[ -x /usr/local/bin/oh-my-posh ]]; then
  export PATH="/usr/local/bin:$PATH"
fi
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/mrdemonwolf-server.omp.json)"

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
if fzf --zsh &>/dev/null; then
  source <(fzf --zsh)
elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi

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
