
if [[ "$(uname)" == "Darwin" ]]; then
  # Homebrew: Apple Silicon at /opt/homebrew, Intel at /usr/local
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -f /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  # Added by OrbStack: command-line tools and integration
  source ~/.orbstack/shell/init.zsh 2>/dev/null || :
fi

# A non-interactive login zsh (`zsh -lc '...'`, which is how the dev boxes get
# driven over SSH) reads this file and never reaches .zshrc, so the CLI paths
# have to be here too. Guarded against duplicates because a login+interactive
# shell runs .zshrc straight after this and adds the same entries.
[[ -d "$HOME/.local/bin" && ":$PATH:" != *":$HOME/.local/bin:"* ]] && \
  export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/.lmstudio/bin" && ":$PATH:" != *":$HOME/.lmstudio/bin:"* ]] && \
  export PATH="$PATH:$HOME/.lmstudio/bin"
