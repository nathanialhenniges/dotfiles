# Orca remote server

Use SSH forwarding to reach a private Orca runtime. The runtime listens on
`127.0.0.1:6769`; no additional public firewall port, Cloudflare Tunnel, or VPN
client is required. Port 6769 leaves Orca's usual SSH runtime port 6768 alone.

## Install

From this dotfiles checkout, on an existing Linux devbox:

```bash
bash scripts/setup-orca-server.sh
```

For a full Linux bootstrap, add `--orca-server` to `server-dev.sh`.

On a Mac mini, run only the server setup without applying workstation dotfiles
or installing the full Brewfile:

```bash
bash install.sh --orca-server-only --dry-run
bash install.sh --orca-server-only
```

Homebrew must already exist if Orca is missing. The installer uses the qualified
`stablyai/orca/orca` cask. A full new-Mac bootstrap can opt in with
`bash install.sh --orca-server`. Default workstation installs and `mini.sh`
do not enable a server. The targeted Mac path was exercised on an M1 Mac mini
with macOS 26.5.2: the launchd service ran and listened only on loopback.

Linux uses the checksum-verified Orca 1.4.257 server-only bundle for arm64/x64.
The per-user service runs as the normal account. Linux lingering keeps it alive
after logout; macOS uses a LaunchAgent and requires the user's login session.
The wrapper activates an existing default fnm Node version for agent commands.

## Connect from the laptop

On the Mac, let launchd keep the forwards for you:

```bash
bash install.sh --orca-tunnels-only        # add --dry-run to preview
orca-tunnels status                        # start | stop | restart [cloud|mini]
```

| Tunnel | Local port | SSH alias | Behaviour |
|---|---|---|---|
| `cloud` | 16768 | `mrdemonwolf-dev` | Starts at login, restarts within ~30 s if it drops |
| `mini` | 16769 | `mdws-mini-dev` | Manual: `orca-tunnels start mini` (Cloudflare may need a browser sign-in) |

The script holds only SSH alias names; addresses and keys stay in
`~/.ssh/config`. Forwards bind `127.0.0.1` only, use `BatchMode` (no
prompts), and log to `~/Library/Logs/orca-tunnels/`. `orca-tunnels stop`
lasts until the next login or start; `orca-tunnels uninstall` removes it all.
Edit `TUNNELS` in `scripts/orca-tunnels.sh` to change aliases or modes.

Manual fallback, if you are not on your own Mac. Keep this running for the
Linux server:

```bash
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:16768:127.0.0.1:6769 <linux-ssh-alias>
```

For the Mac server, use a separate local port:

```bash
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:16769:127.0.0.1:6769 <mac-ssh-alias>
```

On the server, print its private access link:

```bash
bash ~/dotfiles/scripts/setup-orca-server.sh --pairing-link
```

Paste it into Orca's **Settings → Remote Orca Servers → Add server**. Keep the
link private. With `orca-tunnels`, the cloud forward returns by itself after
sleep or a restart; start `mini` again when you need it. Manual forwards must be
reopened by hand. A stale entry paired to an old machine needs a fresh pairing, not a
firewall change or a bypass of server identity checks.

## Service and pairing behavior

Orca creates the user service. In 1.4.257, `orca pair` attempts to widen a
loopback listener, so the managed wrapper uses plain `serve --json` startup
offers and lets systemd/launchd supervise it. Startup output is stored in
`~/.local/share/orca-server/serve-private.log` with mode 0600 inside a 0700
directory. It is never written into this repository or a shared service log.
Rerun setup when a fresh startup offer is needed; existing device grants remain
in Orca's own profile. Do not reset the server identity to fix an old client.

The Linux server-only bundle does not include Orca's browser driver. Project
Playwright tests and Xvfb are separate and can still run on the devbox.

## Cloudflare SSH on the client

`cloudflared` is already included in the workstation Brewfile. If applying only
the client connection settings to an existing Mac, install just that package:

```bash
brew install cloudflared
```

After configuring a tunnel SSH route and an owner-only Access application in
the Cloudflare dashboard, use a private SSH config entry on the client:

```sshconfig
Host my-mac-dev
    HostName ssh.example.com
    User your-user
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ProxyCommand /opt/homebrew/bin/cloudflared access ssh --hostname %h
```

Use the installed `cloudflared` path on Intel Macs. Authenticate interactively
before asking a background SSH forward or Orca to connect. Keep a direct LAN
alias as a recovery path, and verify the server host key independently. The
SSH forward above then uses this alias. Neither WARP nor a public Orca port is
needed. Long-lived sessions can disconnect; keep resumable work on the host.

## Shared communication preferences

Apply the shared ADHD-friendly response preferences without a full bootstrap:

```bash
python3 scripts/apply-agent-instructions.py
```

This preserves existing instructions and updates the home-level AGENTS file,
Codex global instructions, and Claude's global communication rule. Start a new
chat to load changed preferences. Other agents must support the AGENTS path;
this does not change ChatGPT Web custom instructions.

References: [remote servers](https://orca.dev/docs/remote-servers),
[official releases](https://github.com/stablyai/orca/releases).
