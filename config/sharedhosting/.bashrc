# Fix unknown terminal type from Ghostty SSH sessions
[[ "$TERM" == "xterm-ghostty" ]] && export TERM="xterm-256color"

# =============================================================================
# Path
# =============================================================================
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.fzf/bin" ]] && export PATH="$HOME/.fzf/bin:$PATH"

# =============================================================================
# History
# =============================================================================
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# =============================================================================
# Shell Options
# =============================================================================
shopt -s checkwinsize
shopt -s cdspell
shopt -s dirspell 2>/dev/null

# =============================================================================
# Prompt (Oh My Posh or fallback)
# =============================================================================
if command -v oh-my-posh &>/dev/null; then
  eval "$(oh-my-posh init bash --config ~/.config/ohmyposh/mrdemonwolf-sharedhosting.omp.json)"
else
  # Fallback prompt: user@host ~/path (branch) ❯
  __git_branch() {
    git symbolic-ref --short HEAD 2>/dev/null
  }
  PS1='\[\033[0;33m\]\u@\h\[\033[0m\] \[\033[0;34m\]\w\[\033[0m\]$(branch=$(__git_branch); [[ -n "$branch" ]] && echo " \[\033[0;32m\]($branch)\[\033[0m\]") \[\033[0;32m\]❯\[\033[0m\] '
fi

# =============================================================================
# Tab Completion
# =============================================================================
if [[ -f /etc/bash_completion ]]; then
  source /etc/bash_completion
elif [[ -f /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi

# =============================================================================
# fzf
# =============================================================================
if command -v fzf &>/dev/null; then
  if fzf --bash &>/dev/null; then
    eval "$(fzf --bash)"
  elif [[ -f "$HOME/.fzf/shell/key-bindings.bash" ]]; then
    source "$HOME/.fzf/shell/key-bindings.bash"
    source "$HOME/.fzf/shell/completion.bash"
  fi
fi

# =============================================================================
# Custom Aliases
# =============================================================================
[[ -f ~/.aliases ]] && source ~/.aliases

# =============================================================================
# Shell Configuration
# =============================================================================

# ── GPG (commit signing) ───────────────────────────────────
export GPG_TTY=$(tty)

# ── Secrets (API tokens, etc.) ─────────────────────────────
[[ -f ~/.secrets ]] && source ~/.secrets
