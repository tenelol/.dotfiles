import os
import runpy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HOOK_ROOT = Path(__file__).resolve().parents[1]
MARK = HOOK_ROOT / "mark-vault-capture-gate.py"
ENSURE = HOOK_ROOT / "ensure-vault-capture-gate.py"
MARK_NS = runpy.run_path(str(MARK))
ENSURE_NS = runpy.run_path(str(ENSURE))


class VaultCaptureGateHookTests(unittest.TestCase):
    def test_only_substantive_prompts_are_marked(self):
        self.assertTrue(MARK_NS["is_substantive"]("この実装を直して"))
        self.assertFalse(MARK_NS["is_substantive"]("ありがとう"))
        self.assertFalse(MARK_NS["is_substantive"]("この確認ではVault context不要"))

    def test_stop_blocks_once_without_review_marker(self):
        decision_for = ENSURE_NS["decision_for"]
        payload = {"last_assistant_message": "実装完了です。", "stop_hook_active": False}
        self.assertEqual(decision_for(payload, True).get("decision"), "block")
        payload["stop_hook_active"] = True
        self.assertEqual(decision_for(payload, True), {})

    def test_review_marker_or_vault_receipt_allows_stop(self):
        decision_for = ENSURE_NS["decision_for"]
        self.assertEqual(decision_for({"last_assistant_message": MARK_NS["REVIEW_MARKER"]}, True), {})
        self.assertEqual(decision_for({"last_assistant_message": "Vault保存: handoff/example"}, True), {})
        self.assertEqual(decision_for({"last_assistant_message": "done"}, False), {})

    def test_marker_and_stop_hooks_share_turn_state(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "VAULT_CAPTURE_GATE_STATE_DIR": directory}
            marked = subprocess.run(
                [sys.executable, str(MARK)],
                input='{"hook_event_name":"UserPromptSubmit","turn_id":"turn-1","prompt":"実装して"}',
                text=True,
                capture_output=True,
                env=environment,
                check=True,
            )
            self.assertIn("Final Vault capture guard", marked.stdout)
            stopped = subprocess.run(
                [sys.executable, str(ENSURE)],
                input='{"hook_event_name":"Stop","turn_id":"turn-1","stop_hook_active":false,"last_assistant_message":"完了"}',
                text=True,
                capture_output=True,
                env=environment,
                check=True,
            )
            self.assertIn('"decision": "block"', stopped.stdout)


if __name__ == "__main__":
    unittest.main()
