#!/usr/bin/env python3
"""Apply the shared Claude/Codex status-line configuration to this account."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path


ITEMS = [
    "model-with-reasoning",
    "current-dir",
    "git-branch",
    "branch-changes",
    "pull-request-number",
    "context-used",
    "five-hour-limit",
    "weekly-limit",
    "task-progress",
]
COMMAND = "~/.local/share/dotfiles/agent-statusline.py"


def atomic_write(path: Path, data: str, mode: int = 0o600) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(data)
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def backup_first(path: Path) -> None:
    backup = path.with_name(path.name + ".backup")
    if path.exists() and not backup.exists():
        shutil.copy2(path, backup)


def update_toml(text: str) -> str:
    lines = (text or "").splitlines()
    start = next((i for i, line in enumerate(lines) if line.strip() == "[tui]"), None)
    rendered = [
        "status_line = [" + ", ".join(json.dumps(item) for item in ITEMS) + "]",
        "status_line_use_colors = true",
    ]
    if start is None:
        prefix = text or ""
        if prefix and not prefix.endswith("\n"):
            prefix += "\n"
        if prefix and not prefix.endswith("\n\n"):
            prefix += "\n"
        return prefix + "[tui]\n" + "\n".join(rendered) + "\n"

    table_header = re.compile(r'^\s*\[\[?[A-Za-z0-9_-][^]]*\]\]?\s*(?:#.*)?$')
    end = next((i for i in range(start + 1, len(lines)) if table_header.fullmatch(lines[i])), len(lines))
    kept: list[str] = []
    i = start + 1
    while i < end:
        key = lines[i].split("=", 1)[0].strip() if "=" in lines[i] else ""
        if key in {"status_line", "status_line_use_colors"}:
            depth = lines[i].count("[") - lines[i].count("]")
            i += 1
            while depth > 0 and i < end:
                depth += lines[i].count("[") - lines[i].count("]")
                i += 1
            continue
        kept.append(lines[i])
        i += 1
    while kept and not kept[-1].strip():
        kept.pop()
    new_tui = lines[:start + 1] + kept + rendered
    return "\n".join(new_tui + lines[end:]) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="show target paths without changing files")
    parser.add_argument("--claude-only", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    source = repo / "config/agent/shared/statusline.py"
    if not source.is_file():
        parser.error(f"missing shared status-line script: {source}")

    home = Path.home()
    state_dir = home / ".local/share/dotfiles"
    script_target = state_dir / "agent-statusline.py"
    claude_settings = home / ".claude/settings.json"
    codex_config = home / ".codex/config.toml"
    previous_command = state_dir / "claude-statusline-previous-command"

    if args.dry_run:
        print(f"Would install {script_target}")
        print(f"Would merge statusLine into {claude_settings}")
        if not args.claude_only:
            print(f"Would merge tui.status_line into {codex_config}")
        return 0

    for path in (state_dir, home / ".claude", home / ".codex"):
        if path.is_symlink():
            raise ValueError(f"refusing symlink path: {path}")
    state_dir.mkdir(parents=True, exist_ok=True)
    if script_target.exists() and not script_target.is_file():
        raise ValueError(f"status-line target is not a file: {script_target}")
    if claude_settings.is_symlink() or codex_config.is_symlink():
        raise ValueError("refusing to overwrite a symlinked agent config")
    if script_target.is_symlink() or previous_command.is_symlink():
        raise ValueError("refusing symlinked status-line state")

    backup_first(script_target)
    shutil.copy2(source, script_target)
    os.chmod(script_target, 0o755)

    if claude_settings.exists():
        current = json.loads(claude_settings.read_text(encoding="utf-8"))
        if not isinstance(current, dict):
            raise ValueError("Claude settings must contain a JSON object")
    else:
        current = {}

    current_status = current.get("statusLine")
    same_status = isinstance(current_status, dict) and current_status.get("command") == COMMAND
    if not same_status and isinstance(current_status, dict) and current_status.get("command"):
        if not previous_command.exists():
            atomic_write(previous_command, str(current_status["command"]) + "\n")

    current["statusLine"] = {
        "type": "command",
        "command": COMMAND,
        "refreshInterval": 60,
    }
    backup_first(claude_settings)
    atomic_write(claude_settings, json.dumps(current, indent=2, ensure_ascii=False) + "\n")

    if args.claude_only:
        codex_text = None
    elif codex_config.exists():
        codex_text = codex_config.read_text(encoding="utf-8")
    else:
        codex_text = ""
    if codex_text is not None:
        new_codex_text = update_toml(codex_text)
        backup_first(codex_config)
        atomic_write(codex_config, new_codex_text)

    print(f"Installed shared status-line script: {script_target}")
    print(f"Configured Claude Code: {claude_settings}")
    if not args.claude_only:
        print(f"Configured Codex native footer: {codex_config}")
    if previous_command.exists():
        print(f"Preserved previous Claude status command in {previous_command}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
