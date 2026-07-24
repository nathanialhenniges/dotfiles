# Jira / Atlassian MCP setup

Connect Claude Code and Codex on the dev server to Atlassian's official remote
MCP server, which exposes **Jira** and **Confluence** tools (search issues,
read/create/edit issues, page content, etc.).

The server lives at `https://mcp.atlassian.com/v1/mcp` and uses **OAuth** — you
authenticate through a browser once, per tool. This **cannot** be provisioned
headlessly, so `server-dev.sh --agent-setup` only *pre-registers* the server;
the one-time login below is manual.

## Claude Code

`--agent-setup` already runs:

```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp
```

Then authenticate:

1. Start Claude Code on the box: `claude`
2. Run `/mcp`, select **atlassian**, choose **Authenticate**.
3. It prints a URL (and code). Open the URL in the browser **on your laptop**,
   sign in to Atlassian, approve access, enter the code if asked.
4. Back in `/mcp`, atlassian should show **connected**. The token is cached, so
   you won't repeat this each session.

Verify:

```
# in Claude Code
/mcp                      # atlassian = connected
# then ask it to run a Jira search, e.g. "list my open Jira issues"
```

If you didn't run `--agent-setup`, add the server yourself with the
`claude mcp add` line above first.

## Codex

`--agent-setup` writes this block into `~/.codex/config.toml` (via the
`mcp-remote` stdio bridge, since Codex speaks stdio MCP):

```toml
[mcp_servers.atlassian]
command = "npx"
args = ["-y", "mcp-remote", "https://mcp.atlassian.com/v1/mcp"]
startup_timeout_sec = 120
```

First run triggers the OAuth flow:

1. Start Codex: `codex`
2. `mcp-remote` opens/points to an OAuth URL. Open it in the browser **on your
   laptop**, sign in, approve.
3. The token is cached under `~/.mcp-auth/`, so later runs connect silently.

If the browser can't auto-open on the headless box (expected), copy the printed
URL to your laptop manually.

## Notes & troubleshooting

- **Scope:** the OAuth grant covers the Atlassian sites/projects your account
  can see. There's no per-repo-style narrowing like the GitHub PAT — it's your
  Atlassian account's access.
- **`npx` must work:** the Codex path shells out to `npx -y mcp-remote`, so Node
  (installed by `server-dev.sh`) must be on `PATH`. `mcp-remote` is fetched on
  first use.
- **Re-auth:** if a tool starts returning auth errors, the token expired — run
  `/mcp` → Authenticate again (Claude Code), or delete `~/.mcp-auth/` and
  restart Codex.
- **Headless browser:** you only need a browser on the *device you're SSH'd from*
  (your laptop), not on the server. The server just needs outbound HTTPS.
