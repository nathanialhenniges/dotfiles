"""Verify platform setup, private service arguments, and preservation guards."""
import io
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'scripts/setup-orca-server.sh'


class OrcaServerTest(unittest.TestCase):
    def fixture(self, tmp, platform='Linux'):
        home = Path(tmp)
        bindir = home / 'bin'
        bindir.mkdir()
        fnm = home / '.local/share/fnm/fnm'
        fnm.parent.mkdir(parents=True)
        fnm.write_text('#!/bin/sh\nexit 0\n')
        fnm.chmod(0o755)
        cli = '#!/bin/sh\nprintf "%s\\n" "$@" >> "$HOME/cli-calls"\necho "{}"\n'
        archive = home / 'fixture.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            entry = tarfile.TarInfo('orca-server/bin/orca-ide')
            entry.mode = 0o755
            entry.size = len(cli)
            tar.addfile(entry, io.BytesIO(cli.encode()))
        app_cli = home / 'Orca.app/orca'
        app_cli.parent.mkdir()
        app_cli.write_text(cli)
        app_cli.chmod(0o755)
        script = home / 'setup.sh'
        script.write_text(SOURCE.read_text().replace(
            '/Applications/Orca.app/Contents/Resources/bin/orca', str(app_cli)))
        stubs = {
            'uname': f'case "$1" in -m) echo aarch64;; *) echo {platform};; esac',
            'curl': 'echo download >> "$HOME/calls"; while [ "$1" != --output ]; do shift; done; cp "$HOME/fixture.tar.gz" "$2"',
            'sha256sum': 'cat >/dev/null; test "${FAIL_CHECKSUM:-0}" = 0',
            'loginctl': 'echo no',
            'sudo': 'echo "$*" >> "$HOME/sudo-calls"',
        }
        for name, body in stubs.items():
            p = bindir / name
            p.write_text('#!/bin/sh\n' + body + '\n')
            p.chmod(0o755)
        env = dict(os.environ, HOME=tmp, PATH=f'{bindir}:/usr/bin:/bin')

        def run(*args, **extra):
            return subprocess.run(['bash', str(script), *args],
                                  env=dict(env, **extra), capture_output=True, text=True)
        return home, run

    def test_linux_repeats_without_download_and_binds_privately(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            for _ in range(2):
                result = run()
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((home / 'calls').read_text().count('download'), 1)
            args = (home / 'cli-calls').read_text().splitlines()
            self.assertIn('--refuse-public', args)
            self.assertIn('6769', args)
            self.assertIn('127.0.0.1', args)
            self.assertIn('ws://127.0.0.1:16768', args)
            self.assertIn('enable-linger', (home / 'sudo-calls').read_text())
            self.assertNotIn('pair', args)

    def test_mac_reuses_app_and_native_service(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp, 'Darwin')
            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((home / 'calls').exists())
            self.assertIn('ws://127.0.0.1:16769', (home / 'cli-calls').read_text())
            self.assertIn('ORCA_SERVE_RUNTIME=orcad', (home / '.local/bin/orca-server').read_text())
            self.assertFalse((home / 'sudo-calls').exists())

    def test_mac_missing_app_taps_vendor_and_installs_without_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp, 'Darwin')
            (home / 'Orca.app/orca').rename(home / 'Orca.app/orca-fixture')
            brew = home / 'bin/brew'
            brew.write_text('#!/bin/sh\nprintf "%s cleanup=%s\\n" "$*" "${HOMEBREW_NO_INSTALL_CLEANUP:-}" >> "$HOME/brew-calls"\nif [ "$1" = install ]; then cp "$HOME/Orca.app/orca-fixture" "$HOME/Orca.app/orca"; fi\n')
            brew.chmod(0o755)
            result = run()
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = (home / 'brew-calls').read_text().splitlines()
            self.assertEqual(calls, ['tap stablyai/orca cleanup=',
                                     'install --cask stablyai/orca/orca cleanup=1'])

    def test_checksum_failure_never_installs_service(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            self.assertNotEqual(run(FAIL_CHECKSUM='1').returncode, 0)
            self.assertFalse((home / 'cli-calls').exists())
            self.assertFalse((home / '.local/share/orca-server/releases/1.4.257').exists())

    def test_preserves_unmanaged_launcher(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            launcher = home / '.local/bin/orca-server'
            launcher.parent.mkdir(parents=True)
            launcher.write_text('user-owned')
            self.assertNotEqual(run().returncode, 0)
            self.assertEqual(launcher.read_text(), 'user-owned')
            self.assertFalse((home / 'calls').exists())

    def test_dry_run_never_downloads_or_starts(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            result = run('--dry-run')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse((home / 'calls').exists())
            self.assertFalse((home / 'cli-calls').exists())

    def test_loopback_startup_offer_stays_in_private_log(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, run = self.fixture(tmp)
            self.assertEqual(run().returncode, 0)
            (home / 'cli-calls').unlink()
            result = subprocess.run(
                ['bash', str(home / '.local/bin/orca-server'), 'serve', '--supervise', '--no-pairing'],
                env=dict(os.environ, HOME=tmp), capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, '')
            args = (home / 'cli-calls').read_text().splitlines()
            self.assertNotIn('--no-pairing', args)
            self.assertNotIn('--supervise', args)
            self.assertIn('--json', args)
            log = home / '.local/share/orca-server/serve-private.log'
            self.assertEqual(log.stat().st_mode & 0o777, 0o600)
            log.write_text('old: orca://pair?code=old-fixture\n{"url":"orca://pair?code=new-fixture"}\n')
            link = run('--pairing-link')
            self.assertEqual(link.returncode, 0, link.stderr)
            self.assertEqual(link.stdout.strip(), 'orca://pair?code=new-fixture')

    def test_targeted_mac_entrypoint_skips_full_bootstrap(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            checkout = home / 'checkout'
            (checkout / 'lib').mkdir(parents=True)
            (checkout / 'lib/bootstrap.sh').write_text('')
            (checkout / 'scripts').mkdir()
            (checkout / 'scripts/setup-orca-server.sh').write_text('echo "server-helper $*"\n')
            installer = checkout / 'install.sh'
            installer.write_text((ROOT / 'install.sh').read_text())
            bindir = home / 'bin'
            bindir.mkdir()
            uname = bindir / 'uname'
            uname.write_text('#!/bin/sh\necho Darwin\n')
            uname.chmod(0o755)
            env = dict(os.environ, HOME=tmp, PATH=f'{bindir}:/usr/bin:/bin')
            args = ['bash', str(installer), '--orca-server-only', '--dry-run']
            result = subprocess.run(args, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), 'server-helper --dry-run')
            conflict = subprocess.run(args + ['--apply-only'], env=env, capture_output=True, text=True)
            self.assertNotEqual(conflict.returncode, 0)
            self.assertNotIn('server-helper', conflict.stdout)


if __name__ == '__main__':
    unittest.main()
