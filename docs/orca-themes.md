# Personal Orca themes

The PRIVATE [orca-monokai-pro repository](https://github.com/nathanialhenniges/orca-monokai-pro) holds Pro, Classic, Machine, Octagon, Ristretto, Spectrum, Light and Light Sun. Each includes app/editor colors and a matching Ghostty terminal palette. These are personal adaptations, not exact VS Code theme exports.

## Install or update

This is optional and requires explicit access to the private theme repository. Cloning the public dotfiles repo does not grant permission. If your account does not have access, skip this step; the regular dotfiles installer does not fetch these themes.

Install Orca 1.4.246 or later, Git and the GitHub CLI. Enable plugins in Orca Settings > Plugins. Log into the GitHub account with access to the private repository, then run from this dotfiles checkout:

```sh
gh auth login
./install.sh --orca-themes-only
```

Before cloning or updating, the installer uses your GitHub CLI account to check that the repository is accessible and still private. A failed access check stops the command before changing theme files, with guidance to check your login, permissions, or connection. It does not request access or grant permissions automatically. You can check access separately with `gh repo view nathanialhenniges/orca-monokai-pro`.

This only clones or fast-forwards the private plugin, validates it, and registers it in Orca. It does not run the full dotfiles bootstrap. Preview without network or writes with `./install.sh --orca-themes-only --dry-run`.

In Settings > Appearance, select a Monokai variant for the dark or light app/editor theme and the terminal theme. App and terminal choices are separate. Existing Octagon contribution IDs are retained.

The clone lives at `local/orca/monokai-pro-octagon/`; the folder name is retained from the original setup. Keep it there because Orca watches this path. Git ignores it in public dotfiles, but the nested private repository tracks its contents. On another machine, repeat the install commands; no manual palette transfer is needed.

The installer requires the remote to remain private and refuses dirty clones, unexpected origins/branches and symlink destinations. Preserve or commit local theme edits before updating. Git credentials may need refreshing; the script does not store tokens. On macOS it uses the bundled Orca CLI, and on Linux `orca-ide`, avoiding the unrelated GNOME screen reader. `ORCA_CLI_COMMAND` can select the Orca host's CLI.

## Unload

On macOS, from the dotfiles checkout:

```sh
/Applications/Orca.app/Contents/Resources/bin/orca plugin dev unload "$PWD/local/orca/monokai-pro-octagon" --json
```

Select another theme in Appearance. Unloading leaves the clone intact. On Linux use `orca-ide` instead of the macOS executable.

## Keep private

Do not force-add the clone to public dotfiles, make the plugin repo public, or add marketplace discovery topics. This is personal storage, not a community release. [Monokai's license](https://monokai.pro/license) restricts redistribution; private storage does not grant redistribution rights. Palette snapshots come from installed Ghostty themes; UI and syntax mappings are approximations. Hands-on appearance review is separate from validation.
