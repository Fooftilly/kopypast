"""Check Qt positional placeholders in translated messages."""
from pathlib import Path
import re
import sys

import polib

PLACEHOLDER = re.compile(r"%L?[1-9][0-9]*")


def placeholders(text):
    return set(PLACEHOLDER.findall(text))


def main():
    failed = False
    for path in sorted(Path("translate").glob("*.po")):
        for entry in polib.pofile(str(path)):
            if entry.obsolete or "fuzzy" in entry.flags:
                continue
            expected = placeholders(entry.msgid) | placeholders(entry.msgid_plural)
            translations = (
                entry.msgstr_plural.values() if entry.msgid_plural else [entry.msgstr]
            )
            for translation in translations:
                if translation and placeholders(translation) != expected:
                    print(f"{path}:{entry.linenum}: Qt placeholder mismatch: {entry.msgid!r}", file=sys.stderr)
                    failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())
