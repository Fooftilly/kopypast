"""Regression tests for Qt placeholder validation."""
from contextlib import redirect_stderr
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import polib

import check_translations


class TranslationChecks(unittest.TestCase):
    def run_check(self, entry):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.po"
            catalog = polib.POFile()
            catalog.append(entry)
            catalog.save(str(path))
            errors = io.StringIO()
            with patch.object(check_translations.Path, "glob", return_value=[path]):
                with redirect_stderr(errors):
                    result = check_translations.main()
            return result, errors.getvalue()

    def test_reordered_placeholders(self):
        result, _ = self.run_check(polib.POEntry(
            msgid="Restored %1, skipped %2", msgstr="%2 skipped, %1 restored"
        ))
        self.assertEqual(result, 0)

    def test_missing_placeholder(self):
        result, errors = self.run_check(polib.POEntry(
            msgid="Restored %1, skipped %2", msgstr="Restored %1"
        ))
        self.assertEqual(result, 1)
        self.assertIn("Qt placeholder mismatch", errors)

    def test_invalid_plural_form(self):
        result, _ = self.run_check(polib.POEntry(
            msgid="%1 snippet", msgid_plural="%1 snippets",
            msgstr_plural={0: "%1 entry", 1: "entries"}
        ))
        self.assertEqual(result, 1)

    def test_untranslated_entry(self):
        result, _ = self.run_check(polib.POEntry(msgid="%1 snippet", msgstr=""))
        self.assertEqual(result, 0)


if __name__ == "__main__":
    unittest.main()
