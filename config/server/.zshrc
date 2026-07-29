# Fix unknown terminal type from Ghostty SSH sessions
[[ "$TERM" == "xterm-ghostty" ]] && export TERM="xterm-256color"

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

# Oh My Posh prompt
if ! command -v oh-my-posh &>/dev/null; then
  [[ -x "$HOME/.local/bin/oh-my-posh" ]] && export PATH="$HOME/.local/bin:$PATH"
  [[ -x /usr/local/bin/oh-my-posh ]] && export PATH="/usr/local/bin:$PATH"
fi
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/mrdemonwolf-server.omp.json)"

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

# ── fnm (Fast Node Manager) — active only if installed ─────
# Linux installer drops fnm in ~/.local/share/fnm (not on PATH by default).
[[ -d "$HOME/.local/share/fnm" ]] && export PATH="$HOME/.local/share/fnm:$PATH"
command -v fnm &>/dev/null && eval "$(fnm env --use-on-cd --shell zsh)"

# ── Bun — active only if installed ─────────────────────────
# The bun installer writes its own PATH block to ~/.bashrc, never ~/.zshrc,
# so on a zsh box bun is installed but invisible without this.
[[ -d "$HOME/.bun/bin" ]] && export PATH="$HOME/.bun/bin:$PATH"

# ── Secrets (API tokens, etc.) ─────────────────────────────
[[ -f ~/.secrets ]] && source ~/.secrets
