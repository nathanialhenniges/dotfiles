# dotfiles

Personal dotfiles for macOS, managed with simple copy scripts. No symlinks, no stow — just straightforward file syncing.

## What's included

| File | Description |
|------|-------------|
| `.zshrc` | Zsh configuration (Oh My Zsh, plugins, PATH setup) |
| `.zprofile` | Zsh profile (Homebrew init, OrbStack) |
| `.p10k.zsh` | Powerlevel10k prompt configuration |
| `.profile` | Shell profile (ngrok completion) |
| `.aliases` | Custom shell aliases |
| `.gitconfig` | Git configuration (GPG signing, user info) |
| `.npmrc` | npm registry configuration |
| `.nuxtrc` | Nuxt telemetry settings |
| `ohmyposh/mrdemonwolf.omp.json` | Oh My Posh prompt theme |
| `Brewfile` | Homebrew packages, casks, and taps |

## Tools & software

- **Shell:** zsh + [Oh My Zsh](https://ohmyz.sh/)
- **Prompt:** [Oh My Posh](https://ohmyposh.dev/) with custom theme
- **Plugins:** fzf-tab, zsh-autosuggestions, zsh-syntax-highlighting
- **Node:** [fnm](https://github.com/Schniz/fnm) (Fast Node Manager)
- **Terminal:** [Ghostty](https://ghostty.org/)
- **Packages:** Managed via [Homebrew](https://brew.sh/)

## Quick start (new machine)

```bash
git clone https://github.com/nathanialhenniges/dotfiles.git ~/Developer/nathanialhenniges/dotfiles
cd ~/Developer/nathanialhenniges/dotfiles
./install.sh
```

This will:
1. Install Homebrew (if missing)
2. Install all packages from the Brewfile
3. Back up any existing dotfiles (as `*.backup`)
4. Copy dotfiles into place

## Syncing changes

After making changes to your dotfiles on your system:

```bash
./sync.sh
git add .
git commit -m "Update dotfiles"
git push
```

**Important:** After syncing, always review `git diff` before committing to ensure no secrets slip in.

## Adding new dotfiles

1. Add the filename to the `files` array in `sync.sh`
2. Run `./sync.sh` to pull it into the repo
3. Commit and push

For nested files (like `.config/` paths), add a `cp` command in the nested config section of `sync.sh`.

## Secrets

Sensitive values (API keys, tokens) are **never** committed. Instead:

1. Store them in `~/.secrets` on your machine
2. Both `.zshrc` and `.aliases` source `~/.secrets` automatically
3. `.secrets` is in `.gitignore`

## File structure

```
dotfiles/
├── config/           # Dotfiles mirroring ~/
│   ├── .zshrc
│   ├── .zprofile
│   ├── .p10k.zsh
│   ├── .profile
│   ├── .aliases
│   ├── .gitconfig
│   ├── .npmrc
│   ├── .nuxtrc
│   └── .config/
│       └── ohmyposh/
│           └── mrdemonwolf.omp.json
├── Brewfile          # Homebrew packages
├── sync.sh           # Pull dotfiles from system → repo
├── install.sh        # Push dotfiles from repo → system
├── .gitignore
└── README.md
```
