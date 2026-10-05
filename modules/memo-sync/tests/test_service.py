"""Validate the rendered service without launching Automator or Notes."""

from pathlib import Path
import plistlib
import subprocess
import unittest


FILES = Path(__file__).resolve().parents[1] / "files"


class ServiceTests(unittest.TestCase):
    def test_service_enrolls_supported_notes_for_sync(self):
        command_path = "/nix/store/test-memo-sync/bin/memo-sync"
        workflow = (FILES / "register.workflow.plist").read_text().replace("@MEMO_SYNC@", command_path)
        data = plistlib.loads(workflow.encode())
        action = data["actions"][0]["action"]
        self.assertEqual(action["BundleIdentifier"], "com.apple.RunShellScript")
        command = action["ActionParameters"]["COMMAND_STRING"]
        self.assertIn(command_path + " register --sync", command)
        self.assertIn('/usr/bin/open -R "$memo_file"', command)
        self.assertEqual(subprocess.run(["/bin/bash", "-n"], input=command, text=True).returncode, 0)
        self.assertEqual(data["workflowMetaData"]["serviceApplicationBundleID"], "com.apple.Notes")

    def test_registration_is_available_only_from_notes(self):
        info = plistlib.loads((FILES / "service-info.plist").read_bytes())
        service = info["NSServices"][0]
        self.assertEqual(service["NSRequiredContext"]["NSApplicationIdentifier"], "com.apple.Notes")
        self.assertEqual(service["NSSendTypes"], [])
        self.assertEqual(service["NSReturnTypes"], [])
        self.assertEqual(service["NSMessage"], "runWorkflowAsService")


if __name__ == "__main__":
    unittest.main()
