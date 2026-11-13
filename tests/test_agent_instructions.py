import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('instructions', ROOT / 'scripts/apply-agent-instructions.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InstructionsTest(unittest.TestCase):
    def test_preserves_personal_rules_and_updates_without_duplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / '.codex').mkdir()
            path = home / '.codex/AGENTS.md'
            path.write_text('Personal instructions stay.\n')
            for policy in ['old policy', 'new policy', 'new policy']:
                module.apply(home, policy)
            self.assertTrue(path.read_text().startswith('Personal instructions stay.'))
            for relative in ['AGENTS.md', '.codex/AGENTS.md', '.claude/rules/communication.md']:
                text = (home / relative).read_text()
                self.assertEqual(text.count(module.START), 1)
                self.assertIn('new policy', text)
                self.assertNotIn('old policy', text)

    def test_refuses_symlinks_and_malformed_blocks_before_any_write(self):
        for unsafe in ['symlink', 'malformed']:
            with self.subTest(unsafe=unsafe), tempfile.TemporaryDirectory() as tmp:
                home = Path(tmp)
                (home / '.codex').mkdir()
                path = home / '.codex/AGENTS.md'
                if unsafe == 'symlink':
                    path.symlink_to(home / 'outside')
                else:
                    path.write_text(module.START)
                with self.assertRaises(ValueError):
                    module.apply(home, 'policy')
                self.assertFalse((home / 'AGENTS.md').exists())


if __name__ == '__main__':
    unittest.main()
