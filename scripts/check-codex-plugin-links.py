#!/usr/bin/env python3
"""Report plugin cache entries that Codex hook fingerprinting may reject."""

import os
import sys
from pathlib import Path


def main():
    root = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))) / "plugins" / "cache"
    if not root.is_dir():
        print(f"No Codex plugin cache: {root}")
        return 0
    found = []
    for version in root.glob("*/*/*"):
        if version.is_symlink() or not version.is_dir():
            continue
        for directory, dirs, files in os.walk(version, followlinks=False, onerror=lambda e: (_ for _ in ()).throw(e)):
            for name in dirs + files:
                path = Path(directory) / name
                if path.is_symlink():
                    found.append(path)
    for path in sorted(found):
        print(f"symlink: {path}")
    print(f"{len(found)} plugin cache symlink(s) found")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
