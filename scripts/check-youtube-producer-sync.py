#!/usr/bin/env python3
"""Compare the portable Producer skill with its source and built packages."""

import argparse
import re
import runpy
import sys
import zipfile
from pathlib import Path
from tempfile import TemporaryDirectory


def tree_files(folder):
    return {
        path.relative_to(folder).as_posix(): path.read_bytes()
        for path in folder.rglob("*")
        if path.is_file() and ".DS_Store" not in path.parts
    }


def zip_files(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError(f"Damaged ZIP: {path}")
        return {name: archive.read(name) for name in archive.namelist() if not name.endswith("/")}


def version(files):
    match = re.search(rb"\*\*Skill version:\*\* ([0-9.]+)", files["SKILL.md"])
    if not match:
        raise ValueError("SKILL.md has no skill version")
    return match.group(1).decode().rstrip(".")


def check(label, expected, actual):
    if expected == actual:
        print(f"OK  {label}")
        return True
    if isinstance(expected, dict) and isinstance(actual, dict):
        changed = sorted(key for key in expected.keys() | actual.keys() if expected.get(key) != actual.get(key))
        detail = ", ".join(changed)
    else:
        detail = f"expected {expected}, found {actual}"
    print(f"OUT OF SYNC  {label}: {detail}")
    return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--installed", type=Path, default=Path.home() / ".codex/skills/youtube-producer")
    args = parser.parse_args()
    dotfiles = Path(__file__).resolve().parents[1]
    source_repo = Path.home() / "Developer/mrdemonwolf/cli-ai-conversations"
    source_dir = source_repo / ".agents/skills/youtube-producer"
    source = tree_files(source_dir)
    portable = tree_files(dotfiles / "config/agent/codex/skills/youtube-producer")
    installed = tree_files(args.installed)
    standalone = zip_files(source_repo / "mrdemonwolf/youtube/packages/youtube-producer.zip")
    web = zip_files(source_repo / "mrdemonwolf/agent-skills/packages/chatgpt-web/mrdw-youtube-producer.zip")
    package = runpy.run_path(str(source_repo / "mrdemonwolf/agent-skills/scripts/package-skills.py"))
    with TemporaryDirectory() as directory:
        expected_web_zip = Path(directory) / "mrdw-youtube-producer.zip"
        package["write_web_zip"](source_dir, expected_web_zip, "mrdw-youtube-producer", package["WEB_SKILLS"]["mrdw-youtube-producer"])
        expected_web = zip_files(expected_web_zip)
    print(f"Producer version: {version(source)}")
    results = [
        check("source → dotfiles", source, portable),
        check("dotfiles → installed Codex", portable, installed),
        check("source → standalone ZIP", source, standalone),
        check("standalone ZIP copies", standalone, zip_files(source_repo / "mrdemonwolf/agent-skills/packages/skills/youtube-producer.zip")),
        check("source → Web ZIP", expected_web, web),
        check("Web ZIP copies", web, zip_files(source_repo / "mrdemonwolf/agent-skills/packages/skills/mrdw-youtube-producer.zip")),
    ]
    print("ChatGPT Web installed version: verify in ChatGPT; local ZIP checks cannot prove upload.")
    return 0 if all(results) else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (FileNotFoundError, KeyError, ValueError) as error:
        print(f"Cannot verify: {error}", file=sys.stderr)
        sys.exit(1)
