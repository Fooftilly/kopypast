"""Exercise translation generation without modifying the real catalogs."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "translate" / "update-pot.sh"
VALID_PO = (
    'msgid ""\n'
    'msgstr "Content-Type: text/plain; charset=UTF-8\\n"\n'
    '\nmsgid "Hello"\nmsgstr "Translated"\n'
)


class TranslationGeneration(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.translate = self.root / "translate"
        self.translate.mkdir()
        self.script = self.translate / "update-pot.sh"
        shutil.copy2(SCRIPT, self.script)
        self.pot = self.translate / "kopypast.pot"
        self.pot.write_text("old template", encoding="utf-8")
        ui = self.root / "package" / "contents" / "ui"
        ui.mkdir(parents=True)
        (ui / "main.qml").write_text('import QtQuick\nItem { property string greeting: i18n("Hello") }\n', encoding="utf-8")
        (self.translate / "aa.po").write_text(VALID_PO, encoding="utf-8")
        locale = self.root / "package" / "contents" / "locale" / "aa" / "LC_MESSAGES"
        locale.mkdir(parents=True)
        self.mo = locale / "plasma_applet_io.github.fooftilly.kopypast.mo"
        self.mo.write_bytes(b"old catalog")

    def run_generator(self, env=None):
        return subprocess.run(
            ["bash", str(self.script)], cwd=self.root, env=env,
            capture_output=True, text=True, check=False,
        )

    def assert_outputs_unchanged(self):
        self.assertEqual(self.pot.read_text(encoding="utf-8"), "old template")
        self.assertEqual(self.mo.read_bytes(), b"old catalog")

    def test_extraction_failure(self):
        tools = self.root / "tools"
        tools.mkdir()
        xgettext = tools / "xgettext"
        xgettext.write_text("#!/bin/sh\necho extraction-failed >&2\nexit 23\n", encoding="utf-8")
        xgettext.chmod(0o755)
        env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ["PATH"])
        result = self.run_generator(env)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("extraction-failed", result.stderr)
        self.assert_outputs_unchanged()

    def test_compilation_failure(self):
        # The valid catalog sorts first. A later failure must not replace it.
        (self.translate / "zz.po").write_text('msgid "unterminated\n', encoding="utf-8")
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0)
        self.assert_outputs_unchanged()

    def test_success(self):
        result = self.run_generator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('msgid "Hello"', self.pot.read_text(encoding="utf-8"))
        self.assertNotEqual(self.mo.read_bytes(), b"old catalog")
        compiled = subprocess.run(
            ["msgunfmt", str(self.mo)], capture_output=True, text=True, check=True
        )
        self.assertIn('msgstr "Translated"', compiled.stdout)


if __name__ == "__main__":
    unittest.main()
