export ZSH="$HOME/.oh-my-zsh"
plugins=(git fzf-tab zsh-autosuggestions zsh-syntax-highlighting)
ZSH_THEME="robbyrussell"
[[ -x "$(command -v oh-my-posh 2>/dev/null)" ]] && ZSH_THEME=""

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
fi

[[ -f "$HOME/.aliases" ]] && source "$HOME/.aliases"

# Optional CLI integrations stay quiet when the mini does not have dev tools.
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi
command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd cd)"

if command -v brew &>/dev/null; then
  if php_prefix="$(brew --prefix php 2>/dev/null)"; then
    export PATH="$php_prefix/bin:$php_prefix/sbin:$PATH"
  fi
  if cloud_sdk="$(brew --prefix google-cloud-sdk 2>/dev/null)"; then
    [[ -f "$cloud_sdk/share/google-cloud-sdk/path.zsh.inc" ]] && source "$cloud_sdk/share/google-cloud-sdk/path.zsh.inc"
    [[ -f "$cloud_sdk/share/google-cloud-sdk/completion.zsh.inc" ]] && source "$cloud_sdk/share/google-cloud-sdk/completion.zsh.inc"
  fi
fi

if command -v terraform &>/dev/null; then
  autoload -U +X bashcompinit && bashcompinit
  complete -o nospace -C "$(command -v terraform)" terraform
fi
command -v gh &>/dev/null && eval "$(gh completion -s zsh)"
if command -v oh-my-posh &>/dev/null && [[ -f "$HOME/.config/ohmyposh/mrdemonwolf.omp.json" ]]; then
  eval "$(oh-my-posh init zsh --config "$HOME/.config/ohmyposh/mrdemonwolf.omp.json")"
fi
if command -v fzf &>/dev/null && [[ -o zle && -t 0 && -t 1 ]]; then
  source <(fzf --zsh)
fi

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1 "$realpath"'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' switch-group ',' '.'
zstyle ':fzf-tab:*' fzf-flags --bind=tab:accept

bindkey "^[[A" history-search-backward
bindkey "^[[B" history-search-forward

export GPG_TTY="$(tty 2>/dev/null)"
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# Keep user-specific PATH edits outside the shared profile.
[[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"

# ---8<--- LOCAL ---8<---
