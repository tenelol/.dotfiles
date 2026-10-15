import importlib.util
import json
from pathlib import Path
import tempfile
import tomllib
import unittest


FEATURE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("omniwm_preset", FEATURE / "files/apply-rift-preset.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
PRESET = json.loads((FEATURE / "files/rift-preset.json").read_text())


def fixture():
    text = 'schemaVersion = 4\n[general]\nipcEnabled = false\ncustomPreference = "keep me"\n'
    text += '\n[[appRules]]\nid = "existing-rule"\nbundleId = "com.openai.codex"\nminWidth = 800.0\n'
    actions = set(PRESET["hotkeys"])
    actions.update(f"{kind}.{i}" for kind in ("switchWorkspace", "moveToWorkspace") for i in range(9))
    for action in sorted(actions):
        text += f'\n[[hotkeys]]\nid = "{action}"\nbinding = "Unassigned"\n'
    for i in range(1, 10):
        text += f'\n[[workspaces]]\nid = "workspace-{i}"\nname = "{i}"\ndisplayName = "label"\n'
        text += '[workspaces.monitorAssignment]\ntype = "secondary"\n'
    return text


class RiftPresetTests(unittest.TestCase):
    def test_preserves_gui_preferences_ids_and_existing_rule_constraints(self):
        original = fixture()
        changed = module.configure(original, PRESET)
        data = tomllib.loads(changed)
        self.assertEqual(data["general"]["customPreference"], "keep me")
        self.assertTrue(data["general"]["ipcEnabled"])
        self.assertEqual(data["workspaces"][5]["id"], "workspace-6")
        self.assertEqual(data["workspaces"][5]["displayName"], "6")
        self.assertEqual(data["workspaces"][5]["monitorAssignment"]["type"], "secondary")
        codex, = [r for r in data["appRules"] if r.get("bundleId") == "com.openai.codex"]
        self.assertEqual(codex["minWidth"], 800)
        self.assertEqual(codex["id"], "existing-rule")
        self.assertEqual(codex["assignToWorkspace"], "9")
        claude, = [r for r in data["appRules"] if r.get("bundleId") == "com.anthropic.claudefordesktop"]
        self.assertEqual(claude["assignToWorkspace"], "9")
        self.assertEqual(module.configure(changed, PRESET), changed)

    def test_conflicts_and_unknown_schema_leave_file_unchanged(self):
        for text in (
            fixture().replace("schemaVersion = 4", "schemaVersion = 5"),
            fixture() + '\n[[hotkeys]]\nid = "toggleOverview"\nbinding = "Option+H"\n',
        ):
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "settings.toml"
                path.write_text(text)
                with self.assertRaises(ValueError):
                    module.apply(path, PRESET)
                self.assertEqual(path.read_text(), text)

    def test_backup_and_second_apply_does_not_rewrite(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.toml"
            original = fixture()
            path.write_text(original)
            module.apply(path, PRESET)
            backup, = Path(directory).glob("settings.toml.before-rift-*")
            self.assertEqual(backup.read_text(), original)
            before = path.stat()
            module.apply(path, PRESET)
            self.assertEqual((path.stat().st_ino, path.stat().st_mtime_ns), (before.st_ino, before.st_mtime_ns))

    def test_gui_changes_after_initial_apply_are_preserved(self):
        for initial in (fixture(), module.configure(fixture(), PRESET)):
            with self.subTest(initially_matches_preset=initial != fixture()):
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / "settings.toml"
                    path.write_text(initial)
                    module.apply(path, PRESET)
                    edited = path.read_text().replace('binding = "Option+H"', 'binding = "Control+Option+H"')
                    edited = edited.replace('assignToWorkspace = "9"', 'assignToWorkspace = "8"', 1)
                    edited += '\n[[workspaces]]\nid = "workspace-10"\nname = "10"\n'
                    path.write_text(edited)
                    before = path.stat()
                    module.apply(path, PRESET)
                    self.assertEqual(path.read_text(), edited)
                    self.assertEqual(path.stat().st_mtime_ns, before.st_mtime_ns)

    def test_preset_matches_rift_assignments_and_direction_keys(self):
        rift = tomllib.loads((FEATURE.parent / "rift/files/config.toml").read_text())
        expected = {r["app_id"]: str(r["workspace"] + 1)
                    for r in rift["virtual_workspaces"]["app_rules"] if "workspace" in r}
        self.assertEqual(PRESET["appWorkspaces"], expected)
        for key, action in rift["keys"].items():
            for source, target in (("move_focus", "focus"), ("move_node", "move")):
                if isinstance(action, dict) and source in action:
                    expanded = key.replace("move", rift["modifier_combinations"]["move"])
                    binding = expanded.replace("Alt", "Option").replace(" + ", "+")
                    self.assertEqual(PRESET["hotkeys"][target + "." + action[source]], binding)


if __name__ == "__main__":
    unittest.main()
