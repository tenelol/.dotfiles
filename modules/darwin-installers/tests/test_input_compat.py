import unittest
from pathlib import Path

MODULE = (Path(__file__).resolve().parents[1] / "default.nix").read_text()

class InputCompatTests(unittest.TestCase):
    def test_only_the_compatible_standalone_driver_is_installed(self):
        self.assertIn("/releases/download/v6.14.0/Karabiner-DriverKit-VirtualHIDDevice-6.14.0.pkg", MODULE)
        self.assertIn('"org.pqrs.Karabiner-DriverKit-VirtualHIDDevice" = "6.14.0";', MODULE)
        self.assertNotIn("Karabiner-Elements", MODULE)

if __name__ == "__main__":
    unittest.main()
