# Linux desktop shell profile. Server/devbox profiles are separate and frozen.
export PATH="$HOME/.local/bin:$HOME/.local/share/fnm:$PATH"
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000
setopt append_history share_history hist_ignore_all_dups

autoload -Uz compinit
compinit

[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

if [[ -d "$HOME/.local/share/fnm" ]] && command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v gh >/dev/null 2>&1; then
  eval "$(gh completion -s zsh)"
fi

if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  elif [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

if command -v eza >/dev/null 2>&1; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
fi

prompt_theme="$HOME/.config/ohmyposh/mrdemonwolf.omp.json"
if command -v oh-my-posh >/dev/null 2>&1 && [[ -f "$prompt_theme" ]]; then
  eval "$(oh-my-posh init zsh --config "$prompt_theme")"
else
  autoload -Uz colors && colors
  PROMPT='%F{cyan}%n@%m%f %F{blue}%~%f %# '
fi
unset prompt_theme

if [[ -t 0 ]] && command -v tty >/dev/null 2>&1; then
  export GPG_TTY="$(tty)"
fi

[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"

[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
