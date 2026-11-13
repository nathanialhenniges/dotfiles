"""Provision global Claude definitions and append Codex entries without OAuth or clobbering."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PortableMcpTest(unittest.TestCase):
    def test_user_scope_and_existing_config_preserved(self):
        source = (ROOT / 'server-dev.sh').read_text()
        function = 'install_portable_mcps() {' + source.split(
            'install_portable_mcps() {', 1)[1].split('\n}', 1)[0] + '\n}'
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            (home / '.codex').mkdir()
            config = home / '.codex/config.toml'
            original = 'model = "owner-model"\n[plugins.owner]\nenabled = true\n[mcp_servers.atlassian]\ncommand = "owner-bridge"\n'
            config.write_text(original)
            commands = home / 'commands'
            script = f'''set -e
DOTFILES_DIR={json.dumps(str(ROOT))}
substep() {{ :; }}
agent_try() {{ shift; "$@"; }}
claude() {{ printf '%s\\n' "$*" >> "$HOME/commands"; }}
{function}
install_portable_mcps
'''
            env = dict(os.environ, HOME=tmp)
            for _ in range(2):
                result = subprocess.run(['bash', '-c', script], env=env, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
            text = config.read_text()
            self.assertTrue(text.startswith(original))
            parsed = tomllib.loads(text)
            self.assertEqual(parsed['mcp_servers']['atlassian']['command'], 'owner-bridge')
            self.assertEqual(len(parsed['mcp_servers']), 4)
            self.assertEqual(text.count('[mcp_servers.mobbin]'), 1)
            calls = commands.read_text().splitlines()
            self.assertEqual(len(calls), 8)
            self.assertTrue(all('mcp add --scope user --transport http' in c for c in calls))
            for name in ('openaiDeveloperDocs', 'mobbin', 'dub-links'):
                self.assertTrue(any(f'{name} '+parsed['mcp_servers'][name]['url'] in c for c in calls))


if __name__ == '__main__':
    unittest.main()
