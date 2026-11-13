#!/usr/bin/env python3
"""Apply one portable communication policy without replacing personal instructions."""
import os
from pathlib import Path
import tempfile

START = '<!-- dotfiles communication start -->'
END = '<!-- dotfiles communication end -->'


def apply(home, policy):
    if not home.is_absolute() or home == Path('/') or not home.is_dir():
        raise ValueError('HOME must be an existing absolute directory')
    targets = [home / 'AGENTS.md', home / '.codex/AGENTS.md',
               home / '.claude/rules/communication.md']
    updates = []
    for path in targets:
        for part in [path, *path.parents]:
            if part == home:
                break
            if part.is_symlink():
                raise ValueError(f'Refusing symbolic-link instruction path: {part}')
        if path.exists() and not path.is_file():
            raise ValueError(f'Not an instruction file: {path}')
        original = path.read_text() if path.exists() else ''
        if START in original or END in original:
            if original.count(START) != 1 or original.count(END) != 1 or original.index(START) > original.index(END):
                raise ValueError(f'Malformed managed communication block: {path}')
            before, rest = original.split(START, 1)
            _, after = rest.split(END, 1)
            text = before + START + '\n' + policy.rstrip() + '\n' + END + after
        else:
            text = original.rstrip() + ('\n\n' if original.strip() else '')
            text += START + '\n' + policy.rstrip() + '\n' + END + '\n'
        updates.append((path, original, text))
    for path, original, text in updates:
        if text == original:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        if (path.read_text() if path.exists() else '') != original:
            raise ValueError(f'Instructions changed during setup: {path}')
        with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(text)
        try:
            temporary.chmod(path.stat().st_mode & 0o777 if path.exists() else 0o600)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
        print(f'Applied communication preferences: {path}')


if __name__ == '__main__':
    policy = Path(__file__).resolve().parents[1] / 'config/agent/shared/communication.md'
    apply(Path(os.environ.get('HOME', '')), policy.read_text())
