from pathlib import Path
import importlib.util
import plistlib
import tempfile
import unittest
from unittest.mock import patch


FILES = Path(__file__).resolve().parents[1] / "files"
spec = importlib.util.spec_from_file_location("service_installer", FILES / "install_service.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="memo-service-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.destination = self.root / "Services/MemoSyncRegister.workflow"
        self.info = FILES / "service-info.plist"
        self.workflow = FILES / "register.workflow.plist"

    def test_regular_files_and_idempotent_install(self):
        self.assertEqual(installer.install(self.destination, self.info, self.workflow), "installed")
        for name in installer.FILES:
            path = self.destination / "Contents" / name
            self.assertFalse(path.is_symlink())
            self.assertIsInstance(plistlib.loads(path.read_bytes()), dict)
        self.assertEqual(installer.install(self.destination, self.info, self.workflow), "unchanged")

    def test_empty_home_manager_directory_can_be_migrated(self):
        (self.destination / "Contents").mkdir(parents=True)
        self.assertEqual(installer.install(self.destination, self.info, self.workflow), "installed")

    def test_owned_update_replaces_only_verified_bundle(self):
        installer.install(self.destination, self.info, self.workflow)
        changed = self.root / "changed.plist"
        data = plistlib.loads(self.workflow.read_bytes())
        data["AMApplicationBuild"] = "changed"
        changed.write_bytes(plistlib.dumps(data))
        installer.install(self.destination, self.info, changed)
        self.assertEqual((self.destination / "Contents/document.wflow").read_bytes(), changed.read_bytes())
        self.assertEqual(list(self.destination.parent.glob(".memo-sync-backup-*")), [])

    def test_user_edits_and_unmanaged_files_are_preserved(self):
        installer.install(self.destination, self.info, self.workflow)
        document = self.destination / "Contents/document.wflow"
        document.write_text("User edited workflow")
        with self.assertRaises(ValueError):
            installer.install(self.destination, self.info, self.workflow)
        self.assertEqual(document.read_text(), "User edited workflow")

    def test_unmanaged_and_symlink_bundles_are_rejected(self):
        (self.destination / "Contents").mkdir(parents=True)
        (self.destination / "Contents/extra").write_text("Keep")
        with self.assertRaises(ValueError):
            installer.install(self.destination, self.info, self.workflow)
        self.assertEqual((self.destination / "Contents/extra").read_text(), "Keep")
        outside = self.root / "other"
        outside.mkdir()
        link = self.root / "MemoSyncRegister.workflow"
        link.symlink_to(outside)
        with self.assertRaises(ValueError):
            installer.install(link, self.info, self.workflow)

    def test_failed_publish_restores_previous_bundle(self):
        installer.install(self.destination, self.info, self.workflow)
        before = installer.signature(self.destination)
        changed = self.root / "changed.plist"
        data = plistlib.loads(self.workflow.read_bytes())
        data["AMApplicationBuild"] = "changed"
        changed.write_bytes(plistlib.dumps(data))
        rename = installer.os.rename

        def fail_publish(source, target):
            if Path(source).name.startswith(".memo-sync-stage-") and target == self.destination:
                raise OSError("Synthetic publish failure")
            return rename(source, target)

        with patch.object(installer.os, "rename", side_effect=fail_publish):
            with self.assertRaises(OSError):
                installer.install(self.destination, self.info, changed)
        self.assertEqual(installer.signature(self.destination), before)
        self.assertEqual(list(self.destination.parent.glob(".memo-sync-backup-*")), [])


if __name__ == "__main__":
    unittest.main()
