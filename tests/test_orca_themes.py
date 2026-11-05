"""Exercise installer boundaries without GitHub access or a live Orca host."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]


class OrcaThemesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'scripts').mkdir()
        shutil.copyfile(SOURCE / 'scripts/install-orca-themes.sh', self.root / 'scripts/install-orca-themes.sh')
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls'
        self.theme = self.root / 'local/orca/monokai-pro-octagon'
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        ORCA_CLI_COMMAND=str(self.bin / 'fake-orca'), CALLS=str(self.log))
        self.mock('gh', '''if [[ "$2" == view ]]; then echo "${VISIBILITY:-PRIVATE}"; else mkdir -p "$4/.git"; fi''')
        self.mock('git', '''case "$3" in
remote) echo https://github.com/nathanialhenniges/orca-monokai-pro.git ;;
branch) echo main ;;
status) echo -n "${DIRTY:-}" ;;
pull) echo pull >> "$CALLS" ;;
esac''')
        self.mock('fake-orca', 'echo "$2" >> "$CALLS"')

    def mock(self, name, code):
        path = self.bin / name
        path.write_text('#!/bin/bash\nset -eu\n' + code + '\n')
        path.chmod(0o755)

    def run_installer(self, *args):
        return subprocess.run(['bash', str(self.root / 'scripts/install-orca-themes.sh'), *args],
                              env=self.env, text=True, capture_output=True)

    def test_fresh_and_repeat_install(self):
        first = self.run_installer()
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self.run_installer()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.log.read_text().splitlines(), ['validate', 'dev', 'pull', 'validate', 'dev'])

    def test_public_remote_refused(self):
        self.env['VISIBILITY'] = 'PUBLIC'
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertFalse(self.theme.exists())

    def test_dirty_clone_preserved(self):
        (self.theme / '.git').mkdir(parents=True)
        self.env['DIRTY'] = ' M themes/octagon.json'
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_unmanaged_folder_and_symlink_refused(self):
        self.theme.mkdir(parents=True)
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.theme.rmdir()
        self.theme.symlink_to(self.bin, target_is_directory=True)
        self.assertNotEqual(self.run_installer().returncode, 0)
        self.assertFalse(self.log.exists())

    def test_dry_run_makes_no_changes(self):
        self.assertEqual(self.run_installer('--dry-run').returncode, 0)
        self.assertFalse(self.theme.exists())
        self.assertFalse(self.log.exists())


if __name__ == '__main__':
    unittest.main()
