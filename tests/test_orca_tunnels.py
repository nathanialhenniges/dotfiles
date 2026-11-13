"""Verify Orca tunnel LaunchAgents: loopback-only forwards, modes, and guards."""
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scripts/orca-tunnels.sh'
PREFIX = 'com.nathanialhenniges.orca-tunnel'


class OrcaTunnelsTest(unittest.TestCase):
    def fixture(self, tmp, platform='Darwin'):
        home = Path(tmp)
        bindir = home / 'stubs'
        bindir.mkdir()
        stubs = {
            'uname': f'echo {platform}',
            'id': 'echo 501',
            'plutil': 'exit 0',
            'lsof': 'exit 1',
            'launchctl': 'echo "$*" >> "$HOME/launchctl-calls"; [ "$1" != print ] || exit 1',
        }
        for name, body in stubs.items():
            p = bindir / name
            p.write_text('#!/bin/sh\n' + body + '\n')
            p.chmod(0o755)
        env = dict(os.environ, HOME=tmp, PATH=f'{bindir}:/usr/bin:/bin')

        def run(*args):
            return subprocess.run(['bash', str(SOURCE), *args], env=env,
                                  capture_output=True, text=True)
        return home, run

    def agent(self, home, name):
        path = home / f'Library/LaunchAgents/{PREFIX}.{name}.plist'
        return plistlib.loads(path.read_bytes())

    def test_dry_run_writes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            result = run('install', '--dry-run')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('16768', result.stdout)
            self.assertFalse((home / 'Library').exists())
            self.assertFalse((home / 'launchctl-calls').exists())

    def test_install_writes_private_forwards_and_modes(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            for _ in range(2):
                result = run('install')
                self.assertEqual(result.returncode, 0, result.stderr)
            cloud, mini = self.agent(home, 'cloud'), self.agent(home, 'mini')
            self.assertTrue(cloud['RunAtLoad'] and cloud['KeepAlive'])
            self.assertFalse(mini['RunAtLoad'] or mini['KeepAlive'])
            args = cloud['ProgramArguments']
            self.assertEqual(args[0], '/usr/bin/ssh')
            self.assertIn('127.0.0.1:16768:127.0.0.1:6769', args)
            self.assertIn('BatchMode=yes', args)
            self.assertEqual(args[-1], 'mrdemonwolf-dev')
            self.assertIn('127.0.0.1:16769:127.0.0.1:6769', mini['ProgramArguments'])
            for agent in (cloud, mini):
                forward = agent['ProgramArguments'][agent['ProgramArguments'].index('-L') + 1]
                self.assertTrue(forward.startswith('127.0.0.1:'), forward)
            command = home / '.local/bin/orca-tunnels'
            self.assertIn('# Managed by dotfiles orca-tunnels.sh', command.read_text())
            calls = (home / 'launchctl-calls').read_text()
            self.assertEqual(calls.count('bootstrap gui/501'), 4)

    def test_refuses_unmanaged_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            command = home / '.local/bin/orca-tunnels'
            command.parent.mkdir(parents=True)
            command.write_text('#!/bin/sh\necho mine\n')
            result = run('install')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('unmanaged', result.stderr)
            self.assertEqual(command.read_text(), '#!/bin/sh\necho mine\n')

    def test_status_and_uninstall(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            self.assertIn('not installed', run('status').stdout)
            self.assertEqual(run('install').returncode, 0)
            self.assertIn('orca-tunnels start mini', run('status', 'mini').stdout)
            self.assertEqual(run('uninstall').returncode, 0)
            self.assertFalse(list((home / 'Library/LaunchAgents').glob('*.plist')))
            self.assertFalse((home / '.local/bin/orca-tunnels').exists())

    def test_rejects_linux_and_unknown_tunnel(self):
        with tempfile.TemporaryDirectory() as tmp:
            _, run = self.fixture(tmp, platform='Linux')
            self.assertNotEqual(run('status').returncode, 0)
        with tempfile.TemporaryDirectory() as tmp:
            _, run = self.fixture(tmp)
            result = run('status', 'nope')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('unknown tunnel', result.stderr)


if __name__ == '__main__':
    unittest.main()
