#!/bin/bash
# Sync dotfiles from system into this repo.
#
# Capture direction only: system -> repo. The apply direction is install.sh on
# macOS and linux-desktop.sh on Linux, and update.sh picks between them. Which
# files get captured comes from the same per-OS mapping table those two use, so
# running this on the Mac writes config/ and running it on an Ubuntu desktop
# writes profiles/linux-desktop/ — never each other's.
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=lib/bootstrap.sh
source "$DOTFILES_DIR/lib/bootstrap.sh"

profile=""
prune=false
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) profile="${2:-}"; shift 2 ;;
    --prune) prune=true; shift ;;
    -h|--help)
      echo "Usage: ./sync.sh [--profile linux-desktop] [--prune]"
      echo
      echo "Captures this machine's managed dotfiles into the repo. macOS needs"
      echo "no flag. Linux requires --profile, since the server and devbox"
      echo "configs are applied by server-dev.sh and are never captured."
      echo
      echo "The Brewfile merge only ever adds. Entries no longer installed here"
      echo "are reported at the end of every run; --prune removes them."
      exit 0
      ;;
    *) echo "error: unknown option: $1" >&2; exit 1 ;;
  esac
done

detect_os
mappings="$(mappings_for_os "$profile")" || exit 1

# Lines that must never be committed, matched per-file. Nuxt writes a
# machine-specific telemetry.seed into ~/.nuxtrc on first run; without this
# filter it comes straight back on the next sync after being removed.
#
# ponytail: a case, not an associative array. macOS still ships bash 3.2, which
# has no `declare -A`, so this whole loop was aborting with a syntax error and
# nothing on the Mac had actually been syncing.
strip_pattern_for() {
  case "$1" in
    .nuxtrc) printf '%s' '^telemetry\.seed=' ;;
  esac
}

# Rewrite this machine's home directory back to a literal $HOME, so a file
# captured on the Mac still works on the Ubuntu boxes.
#
# ponytail: one sed over everything, not a per-file rule. Installers append
# absolute paths — `export PATH="/Users/you/.local/bin:$PATH"` — and committed
# as-is they are dead weight on Linux, where that path does not exist. There is
# no case where the literal home prefix is the thing we wanted to record.
# The character class keeps the rewrite off a path that merely starts with the
# home string — /Users/you-old stays put, /Users/you" and /Users/you/bin do not.
portable_filter() {
  sed -e "s|${HOME}\([^A-Za-z0-9_.-]\)|\$HOME\1|g" \
      -e "s|${HOME}\$|\$HOME|g"
}

filter_pattern() { # extended regular expression; awk succeeds even if every line matches
  local pattern=$1
  awk -v p="$pattern" '$0 !~ p'
}

sync_file() { # source destination [strip_pattern]
  local source=$1 destination=$2 pattern=${3:-}
  if grep -Eq '(_authToken=|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----)' "$source"; then
    echo "error: refusing to sync secrets from $source" >&2
    return 1
  fi
  mkdir -p "$(dirname "$destination")"
  if [ -n "$pattern" ]; then
    strip_local "${source##*/}" < "$source" | filter_pattern "$pattern" | portable_filter > "$destination"
  else
    strip_local "${source##*/}" < "$source" | portable_filter > "$destination"
  fi
  # Filtering writes a fresh file, so the mode does not come along the way it
  # would with cp. Git tracks the executable bit and install.sh copies it back
  # out, so losing it here would ship ~/.scripts/* unrunnable.
  [ -x "$source" ] && chmod +x "$destination"
  return 0
}

strip_local() { # basename; keeps the marker, drops machine-local lines after it
  case "$1" in
    .zshrc|.zprofile|.profile)
      awk -v m="$LOCAL_MARKER" '{ print } $0 == m { exit }' ;;
    *) cat ;;
  esac
}

resolve_link() { # physical path of a symlink target, including relative links
  local link=$1 target parent depth=0
  while [ -L "$link" ]; do
    depth=$((depth + 1))
    [ "$depth" -le 40 ] || return 1
    target=$(readlink "$link") || return 1
    case "$target" in
      /*) link=$target ;;
      *) link="$(dirname "$link")/$target" ;;
    esac
  done
  parent=$(cd -P "$(dirname "$link")" 2>/dev/null && pwd -P) || return 1
  printf '%s/%s\n' "$parent" "${link##*/}"
}

sync_tree() { # source destination [extra rsync options]
  local source=$1 destination=$2 file root link resolved
  shift 2
  root=$(cd -P "$source" && pwd -P) || return 1
  while IFS= read -r -d '' link; do
    resolved=$(resolve_link "$link") || {
      echo "error: refusing to sync skill tree containing unresolved symlinks" >&2
      return 1
    }
    case "$resolved" in
      "$root"/*) ;;
      *) echo "error: refusing to sync skill tree containing external symlinks" >&2; return 1 ;;
    esac
  done < <(find "$source" -type l -print0)
  while IFS= read -r -d '' file; do
    if grep -Eq '(_authToken=|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----)' "$file" 2>/dev/null; then
      echo "error: refusing to sync skill tree containing secret patterns" >&2
      return 1
    fi
  done < <(find "$source" -type f -print0)
  mkdir -p "$destination"
  rsync -aL --exclude=.DS_Store --exclude=__pycache__/ --exclude='*.pyc' \
    "$@" "$source/" "$destination/"
}

sync_shared_skill_index() { # source destination claude_skills
  local source=$1 destination=$2 claude_skills=$3 entry name target relative
  mkdir -p "$(dirname "$destination")"
  {
    for entry in "$source"/*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      name=${entry##*/}
      if [ -L "$entry" ]; then
        target=$(readlink "$entry")
        case "$target" in
          "$claude_skills"/*) relative=${target#"$claude_skills"/} ;;
          *) continue ;;
        esac
      elif [ -e "$claude_skills/$name" ]; then
        relative=$name
      else
        continue
      fi
      printf '%s\t%s\n' "$name" "$relative"
    done
  } | LC_ALL=C sort > "$destination"
}

echo "Capturing the $OS profile into ${DOTFILES_DIR##*/}/"

synced=0
missing=0
while IFS=: read -r repo_path home_path; do
  [ -n "$repo_path" ] || continue
  if [ ! -f "$HOME/$home_path" ]; then
    echo "  skipped  $home_path (not on this machine)"
    missing=$((missing + 1))
    continue
  fi
  strip_pattern="$(strip_pattern_for "${home_path##*/}")"
  if ! sync_file "$HOME/$home_path" "$DOTFILES_DIR/$repo_path" "$strip_pattern"; then
    exit 1
  fi
  if [ -n "$strip_pattern" ]; then
    echo "  synced   $home_path (filtered)"
  else
    echo "  synced   $home_path"
  fi
  synced=$((synced + 1))
done <<EOF
$mappings
EOF
echo "$synced captured, $missing absent"

# Agent skills are portable across the Mac and Linux dev boxes. Merge instead
# of deleting so one machine cannot erase a skill installed only on another.
if [ -d "$HOME/.claude/skills" ]; then
  if sync_tree "$HOME/.claude/skills" "$DOTFILES_DIR/config/agent/claude/skills"; then
    echo "  synced   .claude/skills"
  else
    echo "  skipped  .claude/skills (contains symlinks or secret patterns)"
  fi
fi
if [ -d "$HOME/.codex/skills" ]; then
  if sync_tree "$HOME/.codex/skills" "$DOTFILES_DIR/config/agent/codex/skills" --exclude=.system/; then
    echo "  synced   .codex/skills (excluding CLI-owned .system)"
  else
    echo "  skipped  .codex/skills (contains symlinks or secret patterns)"
  fi
fi
if [ -d "$HOME/.agents/skills" ]; then
  sync_shared_skill_index "$HOME/.agents/skills" \
    "$DOTFILES_DIR/config/agent/shared-skills.tsv" "$HOME/.claude/skills"
  echo "  synced   .agents/skills index"
fi

echo "Skipped .gitconfig and .npmrc; neither installer applies them, so they stay hand-managed"

# Homebrew is macOS-only here; the Ubuntu boxes get their packages from apt in
# server-dev.sh, which has no equivalent lockfile to refresh.
if [ "$OS" != "Darwin" ]; then
  # Say so rather than exiting 0 in silence. A flag that is quietly ignored
  # reads as "ran fine, nothing to prune", which is the opposite of the truth.
  if [ "$prune" = true ]; then
    echo "Note: --prune had nothing to do. The Brewfile is macOS-only and this is $OS."
  fi
  echo "Done! Review changes with: git diff"
  exit 0
fi

# Merge current system into the Brewfile.
#
# ponytail: union, never subtract. A plain `brew bundle dump --force` rewrites
# the Brewfile to whatever this one Mac happens to have right now, so anything
# installed on another machine — or temporarily uninstalled here — silently
# disappears from the repo and never gets reinstalled on a rebuild. Entries are
# only ever added. Remove one by editing the Brewfile by hand.
brewfile="$DOTFILES_DIR/Brewfile"
dump="$(mktemp)"
merged="$(mktemp)"
trap 'rm -f "$dump" "$merged"' EXIT

brew bundle dump --force --file="$dump"
merge_brewfile "$brewfile" "$dump" "$merged"
added=$(comm -13 <(LC_ALL=C sort "$brewfile") <(LC_ALL=C sort "$merged") | wc -l | tr -d ' ')
mv -f "$merged" "$brewfile"
echo "Brewfile merged ($added added, 0 removed)"

# Because the merge never subtracts, the Brewfile rots silently: an app you
# uninstalled a year ago is still queued for the next machine you build, and
# nothing ever says so. Report it every run; only remove when asked.
orphans="$(mktemp)"
trap 'rm -f "$dump" "$merged" "$orphans"' EXIT
brewfile_orphans "$brewfile" > "$orphans"
orphan_count=$(wc -l < "$orphans" | tr -d ' ')

if [ "$orphan_count" -eq 0 ]; then
  echo "Brewfile is clean: every entry is installed here."
elif [ "$prune" = true ]; then
  pruned="$(mktemp)"
  prune_brewfile "$brewfile" "$pruned"
  mv -f "$pruned" "$brewfile"
  echo "Brewfile pruned ($orphan_count removed):"
  sed 's/^/    - /' "$orphans"
  echo "  Removed only from the rebuild list. Nothing was uninstalled."
else
  echo
  echo "  $orphan_count Brewfile entr$([ "$orphan_count" -eq 1 ] && echo y || echo ies) not installed on this machine:"
  sed 's/^/    /' "$orphans"
  echo
  echo "  Keep them if you still want them on the next machine you build."
  echo "  Drop them with: ./sync.sh --prune"
fi

echo "Done! Review changes with: git diff"
