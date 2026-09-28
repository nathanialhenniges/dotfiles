# WordPress Expert Skill

This package adds a shared WordPress instructions skill for Claude and Codex.

## Install (local sync)

- Claude Desktop (classic skills): copy this folder into `~/.claude/skills/`.
- Codex (ChatGPT/Codex skill loader): copy this folder into your Codex skills directory.

Suggested trigger:

- Use command: `/wp-expert <your-task>`
- Or invoke by listing the skill name: `wordpress-expert`

## Files

- `.claude-plugin/plugin.json` — Claude loader metadata
- `.codex-plugin/plugin.json` — Codex loader metadata
- `skills/wordpress-expert/SKILL.md` — skill instructions
- `commands/wp-expert.md` — easy invocation alias
