"""The edit plan must preserve every image slot, including across replacements."""
import itertools
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "files"))
from notes_text import text_edits


class ImageTextTests(unittest.TestCase):
    def test_replacements_preserve_attachment_slots(self):
        originals = ["a\ufffcb\ufffcc", "\ufffc", "a🌱\n\ufffc日本語\n", "\ufffc\ufffc\n"]
        originals += ["".join(value) for value in itertools.product("ab\ufffc", repeat=4)]
        for original, target in itertools.product(originals, ["", "New\n日本語 🌱", "abc", "a\nb", "bbaa"]):
            current = original
            for start, end, replacement in text_edits(original, target):
                self.assertNotIn("\ufffc", current[start:end])
                current = current[:start] + replacement + current[end:]
            self.assertEqual(current.replace("\ufffc", ""), target)
            self.assertEqual(current.count("\ufffc"), original.count("\ufffc"))
