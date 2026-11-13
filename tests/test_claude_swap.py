"""Exercise the real bootstrap package section with isolated command stubs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ClaudeSwapTest(unittest.TestCase):
    def test_install_rerun_failure_and_linux(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bindir = root / 'bin'
            bindir.mkdir()
            (root / 'lib').mkdir()
            (root / 'lib/bootstrap.sh').write_text('')
            source = (ROOT / 'install.sh').read_text()
            (root / 'install.sh').write_text(source.split('# Install Oh My Zsh if missing')[0])
            stubs = {
                'uname': 'echo "${TEST_OS:-Darwin}"',
                'brew': 'echo "brew $*" >> "$HOME/calls"; case "$1" in --prefix) echo "$HOME";; esac',
                'python3.13': 'exec /usr/bin/env python3 "$@"',
                'sudo': 'exit 0',
                'pipx': '''echo "pipx $*" >> "$HOME/calls"
case "$1" in
runpip) test -f "$HOME/installed";;
install) test "${FAIL_INSTALL:-0}" = 0 || exit 1; touch "$HOME/installed";;
*) exit 1;;
esac''',
            }
            for name, body in stubs.items():
                path = bindir / name
                path.write_text('#!/bin/sh\n' + body + '\n')
                path.chmod(0o755)
            env = dict(os.environ, HOME=tmp, PATH=f'{bindir}:{os.environ["PATH"]}')

            def run(**extra):
                return subprocess.run(['bash', str(root / 'install.sh')],
                                      env=dict(env, **extra), capture_output=True, text=True)

            self.assertEqual(run().returncode, 0)
            self.assertEqual(run().returncode, 0)
            calls = (root / 'calls').read_text()
            self.assertEqual(calls.count('pipx install '), 1)
            self.assertNotIn('upgrade', calls)
            self.assertIn(f'--python {tmp}/bin/python3.13 claude-swap', calls)
            (root / 'installed').unlink()
            self.assertNotEqual(run(FAIL_INSTALL='1').returncode, 0)
            (root / 'calls').unlink()
            self.assertEqual(run(TEST_OS='Linux').returncode, 0)
            self.assertFalse((root / 'calls').exists())


if __name__ == '__main__':
    unittest.main()
