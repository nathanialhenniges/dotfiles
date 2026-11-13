"""Exercise isolated Android setup with fake package managers, never real installs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AndroidToolsTest(unittest.TestCase):
    def fixture(self, tmp):
        home = Path(tmp).resolve()
        bindir = home / 'bin'
        bindir.mkdir()
        jdk = home / 'jdk with spaces'
        (jdk / 'bin').mkdir(parents=True)
        java = jdk / 'bin/java'
        java.write_text('#!/bin/sh\necho "    java.specification.version = 21" >&2\n')
        java.chmod(0o755)
        tools = home / 'brew/share/android-commandlinetools/cmdline-tools/latest/bin'
        tools.mkdir(parents=True)
        manager = tools / 'sdkmanager'
        manager.write_text('''#!/bin/sh
cat >/dev/null
printf '%s\\n' "$@" >> "$HOME/sdk-calls"
test "${SDK_FAIL:-0}" = 0 || exit 9
mkdir -p "$HOME/Library/Android/sdk/platform-tools"
printf '#!/bin/sh\\necho adb-fixture\\n' > "$HOME/Library/Android/sdk/platform-tools/adb"
chmod +x "$HOME/Library/Android/sdk/platform-tools/adb"
''')
        manager.chmod(0o755)
        for name, body in {
            'uname': 'echo "${TEST_OS:-Darwin}"',
            'id': 'echo 501',
            'brew': 'echo "$*" >> "$HOME/brew-calls"; case "$1" in --prefix) echo "$HOME/brew";; list) exit 0;; *) exit 71;; esac',
        }.items():
            p = bindir / name
            p.write_text('#!/bin/sh\n' + body + '\n')
            p.chmod(0o755)
        env = dict(os.environ, HOME=str(home), PATH=f'{bindir}:/usr/bin:/bin', JAVA_HOME=str(jdk))
        env.pop('ANDROID_HOME', None)

        def run(*args, **extra):
            return subprocess.run(['bash', str(ROOT / 'scripts/setup-android-tools.sh'), *args],
                                  env=dict(env, **extra), capture_output=True, text=True)
        return home, env, run

    def test_repeat_preserves_startup_and_existing_sdk(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, env, run = self.fixture(tmp)
            startup = home / '.zshrc'
            startup.write_text('# user config\nexport KEEP_ME=yes\n')
            (home / '.zprofile').write_text('# login config\n')
            sdk = home / 'Library/Android/sdk'
            sdk.mkdir(parents=True)
            sentinel = sdk / 'existing-user-file'
            sentinel.write_text('keep')
            for _ in range(2):
                result = run()
                self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(startup.read_text().count('source "$HOME/.config/dotfiles/android-tools.zsh"'), 1)
            self.assertEqual((home / '.zprofile').read_text().count('source "$HOME/.config/dotfiles/android-tools.zsh"'), 1)
            self.assertEqual((home / '.zshrc.android-tools.backup').read_text(), '# user config\nexport KEEP_ME=yes\n')
            self.assertEqual((home / '.zprofile.android-tools.backup').read_text(), '# login config\n')
            self.assertEqual(sentinel.read_text(), 'keep')
            config = home / '.config/dotfiles/android-tools.zsh'
            self.assertEqual(config.stat().st_mode & 0o777, 0o600)
            check = subprocess.run(['zsh', '-lc', 'set -e; test "$JAVA_HOME" = "$EXPECTED_JAVA"; test "$ANDROID_HOME" = "$HOME/Library/Android/sdk"; adb version'],
                                   env=dict(env, EXPECTED_JAVA=env['JAVA_HOME']), capture_output=True, text=True)
            self.assertEqual(check.returncode, 0, check.stderr)
            packages = (home / 'sdk-calls').read_text()
            self.assertIn('platforms;android-37.0', packages)
            self.assertNotIn('system-images', packages)
            self.assertNotIn('emulator', packages)
            self.assertNotIn('install', (home / 'brew-calls').read_text())

    def test_dry_run_changes_nothing(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, _, run = self.fixture(tmp)
            self.assertEqual(run('--dry-run').returncode, 0)
            self.assertFalse((home / 'brew-calls').exists())
            self.assertFalse((home / 'sdk-calls').exists())
            self.assertFalse((home / '.config').exists())
            self.assertFalse((home / '.zshrc').exists())

    def test_refuses_redirected_sdk_or_startup_before_installing(self):
        for target in ['Library/Android', '.zshrc', '.zprofile']:
            with self.subTest(target=target), tempfile.TemporaryDirectory() as tmp:
                home, _, run = self.fixture(tmp)
                p = home / target
                p.parent.mkdir(parents=True, exist_ok=True)
                p.symlink_to(home / 'elsewhere')
                self.assertNotEqual(run().returncode, 0)
                self.assertFalse((home / 'brew-calls').exists())

    def test_sdk_failure_does_not_rewrite_shell(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, _, run = self.fixture(tmp)
            (home / '.zshrc').write_text('untouched\n')
            self.assertNotEqual(run(SDK_FAIL='1').returncode, 0)
            self.assertEqual((home / '.zshrc').read_text(), 'untouched\n')
            self.assertFalse((home / '.config').exists())

    def test_unmanaged_environment_and_linux_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, _, run = self.fixture(tmp)
            self.assertNotEqual(run(TEST_OS='Linux').returncode, 0)
            p = home / '.config/dotfiles/android-tools.zsh'
            p.parent.mkdir(parents=True)
            p.write_text('user-owned\n')
            self.assertNotEqual(run().returncode, 0)
            self.assertEqual(p.read_text(), 'user-owned\n')
            self.assertFalse((home / 'brew-calls').exists())

    def test_targeted_entrypoint_skips_bootstrap_and_rejects_conflicts(self):
        with tempfile.TemporaryDirectory() as tmp:
            home, env, _ = self.fixture(tmp)
            checkout = home / 'checkout'
            (checkout / 'lib').mkdir(parents=True)
            (checkout / 'lib/bootstrap.sh').write_text('')
            (checkout / 'scripts').mkdir()
            (checkout / 'scripts/setup-android-tools.sh').write_text('echo "android-helper $*"\n')
            (checkout / 'install.sh').write_text((ROOT / 'install.sh').read_text())
            command = ['bash', str(checkout / 'install.sh'), '--android-tools-only', '--dry-run']
            result = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), 'android-helper --dry-run')
            for conflict in ['--apply-only', '--orca-server-only', '--orca-themes-only', '--orca-server', '--android-tools']:
                result = subprocess.run(command + [conflict], env=env, capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('android-helper', result.stdout)


if __name__ == '__main__':
    unittest.main()
