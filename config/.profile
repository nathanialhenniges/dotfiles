if command -v ngrok &>/dev/null; then
  eval "$(ngrok completion)"
fi

# User-installed CLI paths, for the shells that never read .zshrc — `sh -l`,
# `bash -l`, cron. POSIX test and HOME-relative so this file stays valid on the
# Ubuntu boxes too. The PATH check keeps a re-source from stacking duplicates.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH" ;;
esac
case ":$PATH:" in
  *":$HOME/.lmstudio/bin:"*) ;;
  *) [ -d "$HOME/.lmstudio/bin" ] && PATH="$PATH:$HOME/.lmstudio/bin" ;;
esac
export PATH
