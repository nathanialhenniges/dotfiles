#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
dry_run=false
state_ready=false
changed=0
expected_mode="644"

usage() {
  cat <<'EOF'
Usage: ./linux-desktop.sh [--dry-run]

Apply the dedicated Linux desktop profile to the current user's home folder.
This script never uses sudo, installs packages, changes shells, or touches the
server/devbox and agent profiles.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

for argument in "$@"; do
  case "$argument" in
    --dry-run) dry_run=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $argument" ;;
  esac
done

[[ "$(uname -s)" == "Linux" ]] || die "this profile supports Linux desktop sessions only"
[[ "$(id -u)" -ne 0 ]] || die "run this as your normal desktop user, never as root"

home_dir="${HOME:-}"
[[ -n "$home_dir" && "$home_dir" == /* && "$home_dir" != "/" ]] || die "HOME must be a safe absolute path"
[[ -d "$home_dir" ]] || die "HOME does not exist: $home_dir"
home_dir="$(cd "$home_dir" && pwd -P)"
[[ "$home_dir" != "/" ]] || die "refusing to use / as HOME"

state_dir="${XDG_STATE_HOME:-$home_dir/.local/state}"
[[ "$state_dir" == /* && "$state_dir" != "/" ]] || die "XDG_STATE_HOME must be a safe absolute path"
while [[ "$state_dir" == */ ]]; do
  state_dir="${state_dir%/}"
done
case "$state_dir/" in
  *"/../"*|*"/./"*) die "XDG_STATE_HOME must not contain . or .. path components" ;;
esac
case "$state_dir" in
  "$home_dir"|"$home_dir"/*) ;;
  *) die "XDG_STATE_HOME must stay inside HOME: $state_dir" ;;
esac
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
backup_dir="$state_dir/linux-setup/backups/$run_id"
manifest="$backup_dir/manifest.tsv"

mappings=(
  "profiles/linux-desktop/.zshrc:.zshrc"
  "profiles/linux-desktop/.aliases:.aliases"
  "profiles/linux-desktop/.config/ghostty/config:.config/ghostty/config"
  "config/.config/ohmyposh/mrdemonwolf.omp.json:.config/ohmyposh/mrdemonwolf.omp.json"
)

assert_safe_target() {
  local relative="$1" current="$home_dir" part index last_index
  local -a parts

  [[ -n "$relative" && "$relative" != /* ]] || die "unsafe destination: $relative"
  case "/$relative/" in
    *"/../"*|*"/./"*) die "unsafe destination: $relative" ;;
  esac

  IFS='/' read -r -a parts <<< "$relative"
  last_index=$((${#parts[@]} - 1))
  for index in "${!parts[@]}"; do
    part="${parts[$index]}"
    current="$current/$part"
    [[ ! -L "$current" ]] || die "refusing symbolic-link destination: $current"
    if (( index < last_index )); then
      [[ ! -e "$current" || -d "$current" ]] || die "destination parent is not a directory: $current"
    else
      [[ ! -e "$current" || -f "$current" ]] || die "destination is not a regular file: $current"
    fi
  done
}

assert_safe_state_path() {
  local absolute="$1" relative current="$home_dir" part
  local -a parts

  case "$absolute" in
    "$home_dir") return 0 ;;
    "$home_dir"/*) relative="${absolute#"$home_dir"/}" ;;
    *) die "state path escaped HOME: $absolute" ;;
  esac

  case "/$relative/" in
    *"/../"*|*"/./"*) die "unsafe state path: $absolute" ;;
  esac

  IFS='/' read -r -a parts <<< "$relative"
  for part in "${parts[@]}"; do
    current="$current/$part"
    [[ ! -L "$current" ]] || die "refusing symbolic-link state path: $current"
    [[ ! -e "$current" || -d "$current" ]] || die "state parent is not a directory: $current"
  done
}

file_mode() {
  local mode
  if mode="$(stat -c '%a' "$1" 2>/dev/null)"; then
    printf '%s\n' "$mode"
  elif mode="$(stat -f '%Lp' "$1" 2>/dev/null)"; then
    printf '%s\n' "$mode"
  else
    return 1
  fi
}

target_is_current() {
  local source_file="$1" target_file="$2" mode
  [[ -f "$target_file" ]] || return 1
  cmp -s "$source_file" "$target_file" || return 1
  mode="$(file_mode "$target_file")" || return 1
  [[ "$mode" == "$expected_mode" ]]
}

prepare_state() {
  if [[ "$state_ready" == false ]]; then
    mkdir -p "$backup_dir"
    printf 'action\tdestination\tbackup\n' > "$manifest"
    state_ready=true
  fi
}

# Validate every source, destination, and backup path before changing anything.
# A conflict in a later mapping must never leave an earlier file half-applied.
assert_safe_state_path "$backup_dir"
[[ ! -e "$backup_dir" && ! -L "$backup_dir" ]] || die "backup run path already exists: $backup_dir"

for mapping in "${mappings[@]}"; do
  source_relative="${mapping%%:*}"
  target_relative="${mapping#*:}"
  source_file="$repo_dir/$source_relative"

  [[ -f "$source_file" && ! -L "$source_file" ]] || die "invalid profile source: $source_relative"
  assert_safe_target "$target_relative"
done

for mapping in "${mappings[@]}"; do
  source_relative="${mapping%%:*}"
  target_relative="${mapping#*:}"
  source_file="$repo_dir/$source_relative"
  target_file="$home_dir/$target_relative"

  if target_is_current "$source_file" "$target_file"; then
    printf 'unchanged  %s\n' "$target_relative"
    continue
  fi

  if [[ "$dry_run" == true ]]; then
    printf 'would apply %s\n' "$target_relative"
    continue
  fi

  prepare_state
  if [[ -f "$target_file" ]]; then
    backup_file="$backup_dir/$target_relative"
    mkdir -p "$(dirname "$backup_file")"
    cp -p "$target_file" "$backup_file"
    printf 'replace\t%s\t%s\n' "$target_file" "$backup_file" >> "$manifest"
  else
    printf 'create\t%s\t-\n' "$target_file" >> "$manifest"
  fi

  mkdir -p "$(dirname "$target_file")"
  temporary_file="$(mktemp "${target_file}.tmp.XXXXXX")"
  cp "$source_file" "$temporary_file"
  chmod 0644 "$temporary_file"
  mv -f "$temporary_file" "$target_file"
  printf 'applied    %s\n' "$target_relative"
  changed=$((changed + 1))
done

for legacy_dir in "$home_dir/agent" "$home_dir/sharedhosting"; do
  [[ ! -e "$legacy_dir" ]] || printf 'warning: legacy path found; review manually, nothing was moved: %s\n' "$legacy_dir" >&2
done

if [[ "$dry_run" == true ]]; then
  printf 'Dry run complete. No files changed.\n'
elif (( changed == 0 )); then
  printf 'Linux desktop dotfiles are already current.\n'
else
  printf 'Applied %d file(s). Backup manifest: %s\n' "$changed" "$manifest"
  printf 'Open a new terminal to verify the profile.\n'
fi
