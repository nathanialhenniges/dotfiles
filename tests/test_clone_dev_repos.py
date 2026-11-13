#!/usr/bin/env python3
"""Exercise the clone script with fake GitHub responses and isolated homes."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/clone-dev-repos.sh'
FAKE_GH = r'''
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as stream:
    stream.write(json.dumps(args) + '\n')
fixture = json.loads(pathlib.Path(os.environ['FIXTURE']).read_text())
if args[0] == 'api':
    assert '--paginate' in args and 'graphql' in args
    query = args[args.index('-f') + 1]
    assert 'pageInfo { hasNextPage endCursor }' in query
    assert 'ownerAffiliations: [OWNER]' in query
    owner = next(arg.split('=', 1)[1] for arg in args if arg.startswith('owner='))
    print('\n'.join(fixture.get(owner, [])))
    sys.exit(1 if owner == fixture.get('listing_error') else 0)
if args[:2] == ['repo', 'clone']:
    if args[2] == fixture.get('clone_error'):
        sys.exit(1)
    dest = pathlib.Path(args[3])
    dest.mkdir()
    (dest / 'cloned.txt').write_text(args[2])
    sys.exit(0)
raise AssertionError(args)
'''


class CloneReposTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / 'home'
        self.home.mkdir()
        bin_dir = self.base / 'bin'
        bin_dir.mkdir()
        gh = bin_dir / 'gh'
        gh.write_text('#!' + sys.executable + '\n' + FAKE_GH)
        gh.chmod(0o755)
        git = bin_dir / 'git'
        git.write_text('#!/bin/sh\necho "Unexpected git mutation" >&2\nexit 99\n')
        git.chmod(0o755)
        self.fixture = self.base / 'fixture.json'
        self.calls = self.base / 'calls.jsonl'
        self.data = {
            'MrDemonWolf': ['MrDemonWolf/web', 'MrDemonWolf/archived-fork'],
            'nathanialhenniges': ['nathanialhenniges/dotfiles'],
            'kommitai': ['KommitAI/app'],
        }
        self.env = dict(os.environ, HOME=str(self.home), FIXTURE=str(self.fixture),
                        CALLS=str(self.calls), PATH=str(bin_dir) + os.pathsep + os.environ['PATH'])
        self.env.pop('DEV_REPOS_ROOT', None)
        self.env['XDG_CONFIG_HOME'] = str(self.home / '.config')

    def run_script(self, *args):
        self.fixture.write_text(json.dumps(self.data))
        return subprocess.run(['bash', str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True)

    def test_clone_layout_and_safe_rerun(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Cloned: 4', result.stdout)
        marker = self.home / 'Developer/mrdemonwolf/web/cloned.txt'
        marker.write_text('local changes')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Existing: 4', result.stdout)
        self.assertEqual(marker.read_text(), 'local changes')
        self.assertTrue((self.home / 'Developer/kommitai/app').is_dir())

    def test_dry_run_has_no_home_writes(self):
        result = self.run_script('--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Would clone: 4', result.stdout)
        self.assertEqual(list(self.home.iterdir()), [])
        calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
        self.assertEqual(len(calls), 3)
        self.assertTrue(all(args[0] == 'api' for args in calls))

    def test_external_root_with_spaces_and_missing_drive_guard(self):
        external = self.base / 'External Drive/Developer'
        self.env['DEV_REPOS_ROOT'] = str(external)
        result = self.run_script('--dry-run')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(external.exists())
        self.assertFalse(self.calls.exists())
        external.mkdir(parents=True)
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((external / 'mrdemonwolf/web/cloned.txt').is_file())
        self.assertFalse((self.home / 'Developer').exists())

    def test_persisted_external_root_is_used_without_shell_environment(self):
        external = self.base / 'External Drive/Developer'
        external.mkdir(parents=True)
        config = self.home / '.config/dotfiles/dev-repos-root'
        config.parent.mkdir(parents=True)
        config.write_text(str(external) + '\n')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((external / 'kommitai/app/cloned.txt').is_file())
        self.assertFalse((self.home / 'Developer').exists())
        config.write_text('')
        self.assertNotEqual(self.run_script('--dry-run').returncode, 0)

    def test_listing_failure_discards_partial_owner_and_continues(self):
        self.data['listing_error'] = 'MrDemonWolf'
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'Developer/mrdemonwolf').exists())
        self.assertTrue((self.home / 'Developer/kommitai/app').is_dir())
        self.assertIn('Failures: 1', result.stdout)

    def test_clone_failure_continues_and_returns_failure(self):
        self.data['clone_error'] = 'MrDemonWolf/web'
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.home / 'Developer/mrdemonwolf/archived-fork').is_dir())
        self.assertTrue((self.home / 'Developer/kommitai/app').is_dir())
        self.assertIn('Failures: 1', result.stdout)

    def test_existing_destination_symlink_is_skipped(self):
        owner_dir = self.home / 'Developer/mrdemonwolf'
        owner_dir.mkdir(parents=True)
        (owner_dir / 'web').symlink_to(self.base / 'missing-target')
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((owner_dir / 'web').is_symlink())
        self.assertFalse((self.base / 'missing-target').exists())
        self.assertIn('Existing: 1', result.stdout)

    def test_symlinked_parent_refused(self):
        outside = self.base / 'outside'
        outside.mkdir()
        (self.home / 'Developer').symlink_to(outside)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_invalid_repository_path_rejected(self):
        self.data['MrDemonWolf'] = ['MrDemonWolf/../../escape', 'OtherOwner/nope']
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.home / 'Developer/mrdemonwolf').exists())
        self.assertIn('Failures: 2', result.stdout)

    def test_home_layout_is_idempotent(self):
        script = (ROOT / 'server-dev.sh').read_text()
        function = script[script.index('create_home_dirs() {'):].split('\n}', 1)[0] + '\n}'
        command = 'log() { :; }; substep() { :; };\n' + function + '\ncreate_home_dirs\ncreate_home_dirs'
        (self.home / 'Library').mkdir()
        marker = self.home / 'Library/keep'
        marker.write_text('preserve')
        subprocess.run(['bash', '-e', '-c', command], env=self.env, check=True)
        for folder in ['Developer', 'Library', 'Downloads']:
            self.assertTrue((self.home / folder).is_dir())
        self.assertEqual(marker.read_text(), 'preserve')


if __name__ == '__main__':
    unittest.main()
