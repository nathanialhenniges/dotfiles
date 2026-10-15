#!/usr/bin/env python3
"""Powerline-inspired Claude Code status line for the shared dotfiles."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


RESET = "\033[0m"
SEGMENTS = ("\033[48;5;24;38;5;255m", "\033[48;5;237;38;5;81m", "\033[48;5;236;38;5;252m")
NEXT = ("\033[38;5;24m", "\033[38;5;237m", "\033[38;5;236m")


def get(data: dict[str, Any], *path: str, default: Any = None) -> Any:
    value: Any = data
    for key in path:
        if not isinstance(value, dict):
            return default
        value = value.get(key)
    return default if value is None else value


def short_time(timestamp: Any) -> str | None:
    try:
        seconds = max(0, int(float(timestamp) - time.time()))
    except (TypeError, ValueError, OverflowError):
        return None
    if seconds < 3600:
        return f"{max(1, seconds // 60)}m"
    hours, minutes = divmod(seconds // 60, 60)
    return f"{hours}h{minutes:02d}m" if minutes else f"{hours}h"


def progress(value: Any, width: int = 8) -> str:
    try:
        ratio = min(100, max(0, float(value))) / 100
    except (TypeError, ValueError):
        ratio = 0
    filled = round(ratio * width)
    return "█" * filled + "░" * (width - filled)


def segment_line(parts: list[tuple[str, str]], colors: tuple[str, ...]) -> str:
    rendered: list[str] = []
    for index, (label, value) in enumerate(parts):
        color_index = min(index, len(colors) - 1)
        rendered.append(f"{colors[color_index]} {label} {value} ")
        if index + 1 < len(parts):
            rendered.append(f"{NEXT[color_index]}{RESET}")
    return "" + "".join(rendered) + "" + RESET


def wrap_parts(parts: list[tuple[str, str]], width: int) -> list[list[tuple[str, str]]]:
    rows: list[list[tuple[str, str]]] = []
    current: list[tuple[str, str]] = []

    def measured(items: list[tuple[str, str]]) -> int:
        return 2 + sum(len(label) + len(value) + 3 for label, value in items) + max(0, len(items) - 1)

    for label, value in parts:
        available = max(8, width - len(label) - 5)
        if len(value) > available:
            value = value[:available - 1] + "…"
        candidate = current + [(label, value)]
        if current and measured(candidate) > width:
            rows.append(current)
            current = [(label, value)]
        else:
            current = candidate
    if current:
        rows.append(current)
    return rows


def git_state(cwd: str) -> tuple[str | None, str | None]:
    try:
        branch = subprocess.run(
            ["git", "-C", cwd, "branch", "--show-current"],
            check=True, capture_output=True, text=True, timeout=1.0,
        ).stdout.strip() or "detached"
        status = subprocess.run(
            ["git", "-C", cwd, "status", "--porcelain"],
            check=True, capture_output=True, text=True, timeout=2.0,
        ).stdout
        changes = "*" if status.strip() else "clean"
        return branch, changes
    except (OSError, subprocess.SubprocessError):
        return None, None


def previous_status(data: bytes) -> str | None:
    path = Path.home() / ".local/share/dotfiles/claude-statusline-previous-command"
    try:
        command = path.read_text(encoding="utf-8").strip()
        if not command:
            return None
        result = subprocess.run(
            command, shell=True, input=data, capture_output=True, timeout=1.0,
        )
        if result.returncode == 0:
            return result.stdout.decode("utf-8", "replace").strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def main() -> int:
    raw = sys.stdin.buffer.read()
    try:
        data = json.loads(raw or b"{}")
    except (json.JSONDecodeError, UnicodeDecodeError):
        data = {}
    if not isinstance(data, dict):
        data = {}

    model = get(data, "model", "display_name", default="Claude")
    effort = get(data, "effort", "level")
    cwd = str(get(data, "workspace", "current_dir", default=get(data, "cwd", default="")))
    project = Path(cwd).name if cwd else "session"
    branch, changes = git_state(cwd) if cwd else (None, None)
    pr_number = get(data, "pr", "number")

    top: list[tuple[str, str]] = [("CLAUDE", str(model))]
    if effort:
        top[0] = (top[0][0], f"{model} · {effort}")
    top.append(("PROJECT", project))
    if branch:
        top.append(("⎇", f"{branch}{'*' if changes == '*' else ''}"))
    if pr_number:
        top.append(("PR", f"#{pr_number}"))
    if get(data, "fast_mode") is True:
        top.append(("MODE", "FAST"))

    context_pct = get(data, "context_window", "used_percentage")
    bottom: list[tuple[str, str]] = []
    if context_pct is not None:
        pct = int(float(context_pct))
        bottom.append(("CTX", f"{progress(pct)} {pct}% used"))

    limits = get(data, "rate_limits", default={})
    for key, label in (("five_hour", "5H"), ("seven_day", "7D")):
        used = get(limits, key, "used_percentage")
        if used is None:
            continue
        used_num = min(100, max(0, float(used)))
        remaining = round(100 - used_num)
        reset = short_time(get(limits, key, "resets_at"))
        detail = f"{progress(remaining)} {remaining}% left"
        if reset:
            detail += f" · {reset}"
        bottom.append((label, detail))

    spend = get(limits, "spend_limit")
    spend_used = get(spend, "used_usd")
    spend_limit = get(spend, "limit_usd")
    if spend_used is not None and spend_limit is not None:
        period = str(get(spend, "period", default="spend")).upper()
        bottom.append((period, f"${float(spend_used):.2f}/${float(spend_limit):.2f}"))
    else:
        cost = get(data, "cost", "total_cost_usd")
        if cost is not None:
            bottom.append(("SESSION EST.", f"${float(cost):.2f}"))

    try:
        width = max(45, int(os.environ.get("COLUMNS", "120")))
    except ValueError:
        width = 120
    lines = [segment_line(row, SEGMENTS) for row in wrap_parts(top, width)]
    if bottom:
        bottom_colors = ("\033[48;5;238;38;5;255m", "\033[48;5;22;38;5;255m", "\033[48;5;24;38;5;255m")
        lines.extend(segment_line(row, bottom_colors) for row in wrap_parts(bottom, width))
    prior = previous_status(raw)
    if prior:
        lines.append(prior)
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
