"""The edit plan must preserve every image slot, including across replacements."""
import itertools
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "files"))
from notes_text import text_edits, image_layout_key, mapped_offset


class ImageTextTests(unittest.TestCase):
    def test_native_image_line_breaks_do_not_hide_text_or_code_changes(self):
        original = "Head\n\ufffc\nTail\n  code\n"
        rendered = "Head\n\n\ufffc\n\nTail\n  code\n"
        self.assertEqual(image_layout_key(original), image_layout_key(rendered))
        self.assertNotEqual(image_layout_key(original), image_layout_key(rendered.replace("  code", "code")))
        self.assertNotEqual(image_layout_key(original), image_layout_key(rendered.replace("Tail", "Other")))
        offset = original.index("Tail")
        self.assertEqual(mapped_offset(original, rendered, offset), rendered.index("Tail"))

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
