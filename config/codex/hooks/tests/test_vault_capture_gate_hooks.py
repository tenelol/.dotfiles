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

    def test_only_invisible_review_marker_allows_stop(self):
        decision_for = ENSURE_NS["decision_for"]
        self.assertEqual(decision_for({"last_assistant_message": MARK_NS["REVIEW_MARKER"]}, True), {})
        self.assertEqual(
            decision_for(
                {"last_assistant_message": "Vault保存: handoff/example", "stop_hook_active": False},
                True,
            ).get("decision"),
            "block",
        )
        self.assertEqual(decision_for({"last_assistant_message": "done"}, False), {})

    def test_marker_and_stop_hooks_share_turn_state(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "VAULT_CAPTURE_GATE_STATE_DIR": directory}
            marked = subprocess.run(
                [sys.executable, str(MARK)],
                input='{"hook_event_name":"UserPromptSubmit","session_id":"session-1","turn_id":"turn-1","prompt":"実装して"}',
                text=True,
                capture_output=True,
                env=environment,
                check=True,
            )
            self.assertEqual(marked.stdout, "")
            self.assertEqual(len(list(Path(directory).glob("*.required"))), 1)
            stopped = subprocess.run(
                [sys.executable, str(ENSURE)],
                input='{"hook_event_name":"Stop","session_id":"session-1","turn_id":"turn-1","stop_hook_active":false,"last_assistant_message":"完了"}',
                text=True,
                capture_output=True,
                env=environment,
                check=True,
            )
            self.assertIn('"decision": "block"', stopped.stdout)

    def test_subagent_prompt_does_not_activate_parent_capture_gate(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "VAULT_CAPTURE_GATE_STATE_DIR": directory}
            marked = subprocess.run(
                [sys.executable, str(MARK)],
                input=(
                    '{"hook_event_name":"UserPromptSubmit","session_id":"session-sub",'
                    '"turn_id":"turn-sub","agent_id":"agent-1","agent_type":"default",'
                    '"prompt":"調査して"}'
                ),
                text=True,
                capture_output=True,
                env=environment,
                check=True,
            )
            self.assertEqual(marked.stdout, "")
            self.assertEqual(list(Path(directory).glob("*.required")), [])

    def test_same_turn_id_is_isolated_by_session(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = {**os.environ, "VAULT_CAPTURE_GATE_STATE_DIR": directory}
            for session_id in ("session-a", "session-b"):
                subprocess.run(
                    [sys.executable, str(MARK)],
                    input=(
                        '{"hook_event_name":"UserPromptSubmit","session_id":"'
                        + session_id
                        + '","turn_id":"shared-turn","prompt":"実装して"}'
                    ),
                    text=True,
                    capture_output=True,
                    env=environment,
                    check=True,
                )
            self.assertEqual(len(list(Path(directory).glob("*.required"))), 2)


if __name__ == "__main__":
    unittest.main()
