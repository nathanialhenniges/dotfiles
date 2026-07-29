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
# Directory preview on `cd <TAB>`. eza is tolerated-absent on pre-24.04, so guard it.
command -v eza &>/dev/null && \
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'

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

# ── Go — active only if installed ──────────────────────────
# `go install` drops binaries in $GOPATH/bin, which is on nobody's PATH by
# default. Without this the tool installs fine and then cannot be run.
if command -v go &>/dev/null; then
  export GOPATH="$HOME/go"
  export PATH="$GOPATH/bin:$PATH"
fi

# ── direnv — active only if installed ──────────────────────
# server-dev.sh installs direnv but nothing ever hooked it, so .envrc files sat
# there doing nothing.
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ── gh completion — active only if installed ───────────────
command -v gh &>/dev/null && eval "$(gh completion -s zsh)"

# ── Secrets (API tokens, etc.) ─────────────────────────────
[[ -f ~/.secrets ]] && source ~/.secrets
