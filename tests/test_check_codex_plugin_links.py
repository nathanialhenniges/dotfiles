import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/check-codex-plugin-links.py"


class PluginLinkCheck(unittest.TestCase):
    def test_reports_links_inside_versions_but_not_latest_alias(self):
        with tempfile.TemporaryDirectory() as home:
            plugin = Path(home) / "plugins/cache/market/plugin"
            version = plugin / "1.0/node_modules/.bin"
            version.mkdir(parents=True)
            (plugin / "latest").symlink_to("1.0")
            env = {**os.environ, "CODEX_HOME": home}
            run = lambda: subprocess.run(["python3", str(SCRIPT)], env=env, capture_output=True, text=True)
            self.assertEqual(run().returncode, 0)
            (version / "esbuild").symlink_to("../esbuild/bin/esbuild")
            result = run()
            self.assertEqual(result.returncode, 1)
            self.assertIn("esbuild", result.stdout)
            self.assertNotIn("latest", result.stdout)


if __name__ == "__main__":
    unittest.main()
