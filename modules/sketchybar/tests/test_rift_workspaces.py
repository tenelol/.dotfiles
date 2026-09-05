import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPOSITORY = Path(__file__).resolve().parents[3]


class RiftWorkspaceIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.workspaces = self.root / "workspaces.json"
        self.subscriptions = self.root / "subscriptions.json"
        self.calls = self.root / "calls.jsonl"
        self.subscriptions.write_text('{"cli_subscriptions": []}')
        self.bar = self.executable(
            "sketchybar",
            'import json, os, sys\n'
            'with open(os.environ["BAR_CALLS"], "a") as output:\n'
            '    output.write(json.dumps(sys.argv[1:]) + "\\n")\n',
        )
        self.rift = self.executable(
            "rift-cli",
            'import json, os, sys\n'
            'from pathlib import Path\n'
            'args = sys.argv[1:]\n'
            'subscriptions = Path(os.environ["SUBSCRIPTIONS"])\n'
            'if args == ["query", "workspaces"]:\n'
            '    print(Path(os.environ["WORKSPACES"]).read_text())\n'
            'elif args == ["subscribe", "list-cli"]:\n'
            '    print(subscriptions.read_text())\n'
            'elif args == ["subscribe", "unsub-cli", "workspace_changed"]:\n'
            '    subscriptions.write_text(json.dumps({"cli_subscriptions": []}))\n'
            'elif args[:2] == ["subscribe", "cli"]:\n'
            '    options = args[2:]\n'
            '    subscription = {"args": []}\n'
            '    for key, value in zip(options[::2], options[1::2]):\n'
            '        if key == "--args":\n'
            '            subscription["args"].append(value)\n'
            '        else:\n'
            '            subscription[key[2:]] = value\n'
            '    subscriptions.write_text(json.dumps({"cli_subscriptions": [subscription]}))\n'
            'else:\n'
            '    raise SystemExit(f"Unexpected Rift call: {args}")\n',
        )
        self.env = {
            **os.environ,
            "SKETCHYBAR_BIN": str(self.bar),
            "RIFT_CLI": str(self.rift),
            "BAR_CALLS": str(self.calls),
            "WORKSPACES": str(self.workspaces),
            "SUBSCRIPTIONS": str(self.subscriptions),
            "XDG_STATE_HOME": str(self.root / "state"),
            "XDG_CONFIG_HOME": str(self.root / "config"),
            "CONFIG_DIR": str(self.root / "config"),
            "FOCUSED": "",
            "PREVIOUS": "",
            "REFRESH": "",
        }

    def executable(self, name, source):
        path = self.root / name
        path.write_text("#!/usr/bin/env python3\n" + source)
        path.chmod(0o700)
        return path

    def set_workspaces(self, count, active):
        self.workspaces.write_text(json.dumps([
            {"is_active": i == active - 1, "name": str(i + 1), "index": i,
             "id": f"VirtualWorkspaceId({150 + i}v1)", "windows": []}
            for i in range(count)
        ]))

    def run_script(self, path, shell="/bin/sh", **environment):
        source = (REPOSITORY / path).read_text()
        # Keep the fixtures on the Rift branch even when AeroSpace is running.
        source = source.replace("/usr/bin/pgrep", "/usr/bin/false")
        subprocess.run([shell], input=source, text=True, check=True,
                       env={**self.env, **environment}, capture_output=True)

    def bar_calls(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()]

    def test_highlight_uses_workspace_index_instead_of_internal_id(self):
        self.set_workspaces(9, active=9)
        self.run_script("modules/sketchybar/files/plugins/spaces.sh",
                        FOCUSED="158", REFRESH="all")
        calls = self.bar_calls()
        self.assertEqual(len(calls), 9)
        self.assertEqual(calls[-1], ["--set", "space.9.9", "label.color=0xcff5f7fa"])

        self.calls.write_text("")
        self.set_workspaces(9, active=3)
        self.run_script("modules/sketchybar/files/plugins/spaces.sh", FOCUSED="152")
        self.assertEqual(self.bar_calls(), [
            ["--set", "space.9.9", "label.color=0x78f5f7fa"],
            ["--set", "space.3.3", "label.color=0xcff5f7fa"],
        ])

    def test_bar_uses_rift_workspace_count_and_actual_active_index(self):
        self.set_workspaces(3, active=3)
        self.run_script("modules/sketchybar/files/sketchybarrc", shell="/bin/bash")
        calls = self.bar_calls()
        items = [args[2] for args in calls if args[:2] == ["--add", "item"]
                 and args[2].startswith("space.")
                 and not args[2].startswith("space.separator.")]
        self.assertEqual(items, ["space.1.1", "space.2.2", "space.3.3"])
        self.assertIn(["--trigger", "workspace_change", "FOCUSED=3", "REFRESH=all"], calls)

    def test_dynamic_workspace_numbers_are_not_wrapped_at_nine(self):
        self.set_workspaces(12, active=12)
        self.run_script("modules/sketchybar/files/plugins/spaces.sh", REFRESH="all")
        self.assertEqual(self.bar_calls()[-1],
                         ["--set", "space.12.12", "label.color=0xcff5f7fa"])

    def test_subscription_refreshes_without_interpreting_internal_ids(self):
        script = "modules/rift/files/sketchybar-workspace-subscribe"
        self.subscriptions.write_text(json.dumps({"cli_subscriptions": [
            {"event": "workspace_changed", "command": "/bin/sh", "args": ["old callback"]}
        ]}))
        self.run_script(script)
        first = self.subscriptions.read_text()
        self.run_script(script)
        self.assertEqual(self.subscriptions.read_text(), first)
        subscription, = json.loads(first)["cli_subscriptions"]
        event = json.dumps({"workspace_id": {"idx": 158, "version": 1}, "workspace_name": "9"})
        subprocess.run([subscription["command"], *subscription["args"], event],
                       check=True, env=self.env, capture_output=True)
        self.assertEqual(self.bar_calls(), [["--trigger", "workspace_change", "REFRESH=all"]])


if __name__ == "__main__":
    unittest.main()
