#!/bin/bash
# Physical-device Android development on macOS; no IDE or emulator.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
dry_run=false
case "${1:-}" in
  --dry-run) dry_run=true; shift ;;
  -h|--help) echo 'Usage: setup-android-tools.sh [--dry-run]'; exit 0 ;;
esac
[[ $# == 0 ]] || die "unknown option: $1"
[[ $(uname -s) == Darwin ]] || die 'Android tools setup supports macOS only'
[[ $(id -u) != 0 ]] || die 'run as your normal macOS user, not root'
[[ ${HOME:-} == /* && $HOME != / && -d $HOME ]] || die 'HOME must be an existing absolute directory'
sdk_root="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
[[ $sdk_root == /* && $sdk_root != / ]] || die 'ANDROID_HOME must be an absolute SDK directory'
case "/$sdk_root/" in *'/../'*|*'/./'*) die 'unsafe SDK path' ;; esac
config_dir="$HOME/.config/dotfiles"
environment_file="$config_dir/android-tools.zsh"
marker='# Managed by dotfiles setup-android-tools.sh'
# shellcheck disable=SC2016
hook='[[ -r "$HOME/.config/dotfiles/android-tools.zsh" ]] && source "$HOME/.config/dotfiles/android-tools.zsh"'

# Refuse redirected destinations before installing packages or modifying files.
for target in "$sdk_root" "$config_dir"; do
  current="$target"
  while [[ $current != / ]]; do
    [[ ! -L $current && ( ! -e $current || -d $current ) ]] || die "unsafe directory: $current"
    current=$(dirname "$current")
  done
done
for target in "$HOME/.zshrc" "$HOME/.zshrc.android-tools.backup" "$HOME/.zprofile" "$HOME/.zprofile.android-tools.backup" "$environment_file"; do
  [[ ! -L $target && ( ! -e $target || -f $target ) ]] || die "unsafe file: $target"
done
if [[ -e $environment_file ]] && ! grep -Fxq "$marker" "$environment_file"; then
  die "refusing unmanaged environment file: $environment_file"
fi

packages=(platform-tools 'platforms;android-36' 'platforms;android-37.0' 'build-tools;36.0.0' 'build-tools;37.0.0')
if [[ $dry_run == true ]]; then
  echo "Would reuse/install Java 21 and Homebrew android-commandlinetools."
  printf 'Would install in %s: %s\n' "$sdk_root" "${packages[*]}"
  echo "Would accept the required SDK package licenses and configure Zsh."
  echo 'No Android Studio, emulator, system images, NDK, device pairing, or public ADB listener.'
  exit 0
fi

if ! command -v brew >/dev/null; then
  for prefix in /opt/homebrew /usr/local; do
    [[ ! -x $prefix/bin/brew ]] || export PATH="$prefix/bin:$PATH"
  done
fi
command -v brew >/dev/null || die 'install Homebrew first; targeted setup does not bootstrap it'

is_java21() {
  [[ -n $1 && -x $1/bin/java ]] && "$1/bin/java" -XshowSettings:properties -version 2>&1 |
    grep -Eq '^[[:space:]]*java.specification.version = 21$'
}
java_home=''
for candidate in "${JAVA_HOME:-}" "$HOME/.local/share/java/temurin-21.jdk/Contents/Home"; do
  if is_java21 "$candidate"; then java_home="$candidate"; break; fi
done
if [[ -z $java_home ]]; then
  candidate=$(/usr/libexec/java_home -v 21 2>/dev/null || true)
  if is_java21 "$candidate"; then java_home="$candidate"; fi
fi
if [[ -z $java_home ]]; then
  HOMEBREW_NO_INSTALL_CLEANUP=1 brew install --cask temurin@21
  java_home=$(/usr/libexec/java_home -v 21)
fi
is_java21 "$java_home" || die 'a working Java 21 JDK is required'
export JAVA_HOME="$java_home"

if ! brew list --cask android-commandlinetools >/dev/null 2>&1; then
  HOMEBREW_NO_INSTALL_CLEANUP=1 brew install --cask android-commandlinetools
fi
tools_bin="$(brew --prefix)/share/android-commandlinetools/cmdline-tools/latest/bin"
[[ -x $tools_bin/sdkmanager ]] || die 'Android SDK command-line tools are missing'
mkdir -p "$sdk_root"
# Finite input accepts only licenses requested by these selected packages.
# shortcut: sdkmanager supports existing SDKs; migrate when Google removes this compatibility CLI.
printf 'y\n%.0s' {1..40} | "$tools_bin/sdkmanager" --sdk_root="$sdk_root" --install "${packages[@]}"
[[ -x $sdk_root/platform-tools/adb ]] || die 'SDK platform-tools installation did not provide adb'
"$sdk_root/platform-tools/adb" version

mkdir -p "$config_dir"
temporary=$(mktemp "$config_dir/android-tools.XXXXXX")
trap 'rm -f "$temporary"' EXIT
{
  printf '%s\n' "$marker"
  printf 'export JAVA_HOME=%q\n' "$java_home"
  printf 'export ANDROID_HOME=%q\n' "$sdk_root"
  # shellcheck disable=SC2016
  printf 'export PATH="$ANDROID_HOME/platform-tools:%s:$JAVA_HOME/bin:$PATH"\n' "$tools_bin"
} > "$temporary"
chmod 600 "$temporary"
mv "$temporary" "$environment_file"
for startup in "$HOME/.zshrc" "$HOME/.zprofile"; do
  if [[ ! -f $startup ]] || ! grep -Fxq "$hook" "$startup"; then
    if [[ -f $startup && ! -e $startup.android-tools.backup ]]; then
      cp -p "$startup" "$startup.android-tools.backup"
      chmod 600 "$startup.android-tools.backup"
    fi
    printf '\n%s\n' "$hook" >> "$startup"
  fi
done
echo "Android tools ready. Open a new terminal, then run: adb devices -l"
echo 'Approve USB debugging on the phone, or use adb pair for wireless debugging.'
