import unittest
from pathlib import Path


MODULE = (Path(__file__).resolve().parents[1] / "default.nix").read_text()


class InputCompatBrewfileTests(unittest.TestCase):
    def test_custom_karabiner_cask_keeps_its_tap_declared(self):
        self.assertIn('name = "tenelol/input-compat";', MODULE)
        self.assertIn('"tenelol/input-compat/karabiner-elements"', MODULE)
        self.assertNotIn('\n        "karabiner-elements"\n', MODULE)


if __name__ == "__main__":
    unittest.main()
