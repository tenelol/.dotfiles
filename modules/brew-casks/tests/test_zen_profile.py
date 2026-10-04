import importlib.util
import tempfile
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location("zen_profile", Path(__file__).parents[1] / "files/preserve-zen-profile.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ProfileMigrationTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.base = self.home / "Library/Application Support/zen"
        (self.base / "Profiles/old").mkdir(parents=True)
        (self.base / "Profiles/other").mkdir()
        self.profiles = self.base / "profiles.ini"
        self.profiles.write_text("[Profile0]\nPath=Profiles/other\nDefault=1\n[InstallOLD]\nDefault=Profiles/old\nLocked=1\n")

    def test_preserves_install_default_instead_of_legacy_global_default(self):
        self.assertEqual(module.preserve(self.home, "NEW", "OLD"), "Profiles/old")
        self.assertEqual(module.parser((self.base / "installs.ini").read_text())["NEW"]["Default"], "Profiles/old")
        self.assertEqual(module.parser(self.profiles.read_text())["Profile0"]["Default"], "1")

    def test_future_update_respects_users_changed_previous_install_default(self):
        module.preserve(self.home, "NEW", "OLD")
        self.profiles.write_text(self.profiles.read_text().replace("[InstallNEW]\nDefault=Profiles/old", "[InstallNEW]\nDefault=Profiles/other"))
        self.assertEqual(module.preserve(self.home, "NEXT", "OLD"), "Profiles/other")

    def test_existing_new_install_selection_is_not_overwritten(self):
        self.profiles.write_text(self.profiles.read_text() + "[InstallNEW]\nDefault=Profiles/other\nLocked=1\n")
        before = self.profiles.read_bytes()
        self.assertEqual(module.preserve(self.home, "NEW", "OLD"), "Profiles/other")
        self.assertEqual(before, self.profiles.read_bytes())

    def test_empty_install_section_uses_previous_selection(self):
        self.profiles.write_text(self.profiles.read_text() + "[InstallNEW]\nLocked=1\n")
        self.assertEqual(module.preserve(self.home, "NEW", "OLD"), "Profiles/old")
        self.assertEqual(module.parser(self.profiles.read_text())["InstallNEW"]["Default"], "Profiles/old")

    def test_unknown_previous_install_does_not_modify_profiles(self):
        before = self.profiles.read_bytes()
        with self.assertRaises(RuntimeError):
            module.preserve(self.home, "NEW", "UNKNOWN")
        self.assertEqual(before, self.profiles.read_bytes())

    def test_missing_selected_profile_is_rejected(self):
        self.profiles.write_text(self.profiles.read_text().replace("Default=Profiles/old", "Default=Profiles/missing"))
        with self.assertRaises(RuntimeError):
            module.preserve(self.home, "NEW", "OLD")

    def test_concurrent_selection_change_is_rejected(self):
        with self.assertRaises(RuntimeError):
            module.atomic_write(self.profiles, "replacement", "outdated contents")

    def test_mutable_destination_hash_does_not_follow_old_nix_link(self):
        old = self.home / "nix-store/Zen.app"
        (old / "Contents/MacOS").mkdir(parents=True)
        link = self.home / "Applications/Zen.app"
        link.parent.mkdir()
        link.symlink_to(old)
        self.assertEqual(module.install_directory(link), str((old / "Contents/MacOS").resolve()))
        self.assertEqual(module.install_directory(link, literal=True), str(link / "Contents/MacOS"))

    def test_normal_copy_keeps_current_nix_install_profile(self):
        state = self.home / ".local/state/dotfiles/zen-install.json"
        state.parent.mkdir(parents=True)
        state.write_text('{"hash":"OLD"}')
        self.assertEqual(module.preserve(self.home, "NORMAL", "OTHER"), "Profiles/old")
        self.assertEqual(module.preserve(self.home, "NORMAL", "NORMAL"), "Profiles/old")

    def test_normal_copy_replaces_stale_homebrew_mapping_with_current_selection(self):
        state = self.home / ".local/state/dotfiles/zen-install.json"
        state.parent.mkdir(parents=True)
        state.write_text('{"hash":"OLD"}')
        self.profiles.write_text(self.profiles.read_text() + "[InstallNORMAL]\nDefault=Profiles/other\nLocked=1\n")
        self.assertEqual(module.preserve(self.home, "NORMAL", "OLD", prefer_previous=True), "Profiles/old")
        self.assertEqual(module.parser(self.profiles.read_text())["InstallNORMAL"]["Default"], "Profiles/old")
        # Later switches preserve a new profile the user selects in the normal app.
        self.profiles.write_text(self.profiles.read_text().replace("[InstallNORMAL]\nDefault=Profiles/old", "[InstallNORMAL]\nDefault=Profiles/other"))
        self.assertEqual(module.preserve(self.home, "NORMAL", "NORMAL", prefer_previous=True), "Profiles/other")


if __name__ == "__main__":
    unittest.main()
