import json
from pathlib import Path
import re
import subprocess
import unittest


class DarwinTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture = Path(__file__).with_name("darwin.nix-test")
        cls.config = json.loads(subprocess.check_output(
            ["nix-instantiate", "--eval", "--strict", "--json", str(fixture)], text=True
        ))

    def test_driver_runs_without_karabiner_elements(self):
        service = self.config["services"]["kanata-vhid"]["serviceConfig"]
        self.assertEqual(service["ProgramArguments"], [
            "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/"
            "Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
        ])
        self.assertTrue(service["KeepAlive"])
        self.assertTrue(service["RunAtLoad"])

    def test_migration_preserves_driver_and_starts_it_before_kanata(self):
        script = self.config["activation"]
        unregister = script.index('"$daemons" unregister-core-daemons')
        remove_app = re.search(r"/bin/rm -rf \\\n\s+/Applications/Karabiner-Elements\.app", script).start()
        start_driver = script.index("/bin/launchctl kickstart -k system/org.nixos.kanata-vhid")
        start_kanata = script.index("/bin/launchctl kickstart -k system/org.nixos.kanata >")
        self.assertLess(unregister, remove_app)
        self.assertLess(remove_app, start_driver)
        self.assertLess(start_driver, start_kanata)
        self.assertNotIn("uninstall.sh", script)
        self.assertNotIn("uninstall_core.sh", script)
        self.assertNotIn("--forget org.pqrs.Karabiner-DriverKit-VirtualHIDDevice", script)

    def test_activation_shell_syntax_and_disabled_cleanup(self):
        for key in ("activation", "disabled"):
            subprocess.run(["/bin/bash", "-n"], input=self.config[key], text=True, check=True)
        self.assertIn("bootout system/org.nixos.kanata-vhid", self.config["disabled"])
        self.assertNotIn("launchctl enable", self.config["disabled"])


if __name__ == "__main__":
    unittest.main()
