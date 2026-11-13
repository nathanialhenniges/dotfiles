"""Run the server's real installer with isolated package commands and credentials."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ServerClaudeSwapTest(unittest.TestCase):
    def test_install_repeat_and_failure_preserve_login(self):
        source = (ROOT / 'server-dev.sh').read_text()
        function = 'install_claude_swap() {' + source.split(
            'install_claude_swap() {', 1)[1].split('\n}', 1)[0] + '\n}'
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            bindir = home / '.local/bin'
            bindir.mkdir(parents=True)
            credentials = home / '.claude/.credentials.json'
            credentials.parent.mkdir()
            credentials.write_text('existing-login-fixture')
            stubs = {
                'pipx': '''echo "$*" >> "$HOME/calls"
case "$1" in
runpip) test -f "$HOME/installed";;
install) test "${FAIL_INSTALL:-0}" = 0 || exit 1
         touch "$HOME/installed";;
*) exit 1;;
esac''',
                'cswap': 'echo "unexpected cswap execution" >&2; exit 99',
                'sudo': 'echo "unexpected apt execution" >&2; exit 99',
            }
            for name, body in stubs.items():
                path = bindir / name
                path.write_text('#!/bin/sh\n' + body + '\n')
                path.chmod(0o755)
            env = dict(os.environ, HOME=tmp, PATH=f'{bindir}:/usr/bin:/bin')

            def run(**extra):
                return subprocess.run(['bash', '-ec',
                                       'log() { :; }; substep() { :; };\n' +
                                       function + '\ninstall_claude_swap'],
                                      env=dict(env, **extra), capture_output=True, text=True)

            self.assertEqual(run().returncode, 0)
            self.assertEqual(run().returncode, 0)
            self.assertEqual((home / 'calls').read_text().count('install --python python3 claude-swap'), 1)
            self.assertNotIn('upgrade', (home / 'calls').read_text())
            (home / 'installed').unlink()
            self.assertNotEqual(run(FAIL_INSTALL='1').returncode, 0)
            self.assertEqual(credentials.read_text(), 'existing-login-fixture')
            self.assertIn('.local/bin', (ROOT / 'config/server/.zshrc').read_text())


if __name__ == '__main__':
    unittest.main()
