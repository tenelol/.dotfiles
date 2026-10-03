import unittest
from pathlib import Path

MODULE = (Path(__file__).resolve().parents[1] / "default.nix").read_text()

class InputCompatTests(unittest.TestCase):
    def test_original_karabiner_and_hid_versions_are_preserved(self):
        self.assertIn("/releases/download/v16.0.0/Karabiner-Elements-16.0.0.dmg", MODULE)
        self.assertIn('"org.pqrs.Karabiner-Elements" = "16.0.0";', MODULE)
        self.assertIn('"org.pqrs.Karabiner-DriverKit-VirtualHIDDevice" = "6.14.0";', MODULE)
        self.assertNotIn("casks.karabiner-elements", MODULE)

if __name__ == "__main__":
    unittest.main()
