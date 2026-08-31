#!/usr/bin/env python3
"""Regression tests for run_model_agent.py using a fake Codex executable."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


SCRIPT = Path(__file__).with_name("run_model_agent.py")
SKILL_ROOT = SCRIPT.parents[1]
SKILL = SKILL_ROOT / "SKILL.md"
POLICY = SKILL_ROOT / "references" / "routing-policy.md"


CATALOG = {
    "models": [
        {
            "slug": slug,
            "visibility": "list",
            "supported_reasoning_levels": [
                {"effort": effort}
                for effort in ("low", "medium", "high", "xhigh", "max", "ultra")
            ],
        }
        for slug in ("gpt-5.6-luna", "gpt-5.6-terra", "gpt-5.6-sol", "gpt-5.4-mini")
    ]
}


class RunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.capture = self.root / "capture.json"
        self.fake_codex = self.root / "fake-codex"
        self.fake_codex.write_text(
            textwrap.dedent(
                f"""\
                #!{sys.executable}
                import json
                import os
                from pathlib import Path
                import sys

                catalog = {json.dumps(CATALOG)!r}
                if sys.argv[1:3] == ["debug", "models"]:
                    print(catalog)
                    raise SystemExit(0)

                prompt = sys.stdin.read()
                Path(os.environ["ROUTER_CAPTURE"]).write_text(
                    json.dumps({{"argv": sys.argv[1:], "stdin": prompt}}),
                    encoding="utf-8",
                )
                args = sys.argv[1:]
                output = Path(args[args.index("--output-last-message") + 1])
                output.write_text("WORKER_OK", encoding="utf-8")
                """
            ),
            encoding="utf-8",
        )
        self.fake_codex.chmod(0o755)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def run_router(self, *args: str, prompt: str = "Do the task") -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["ROUTER_CAPTURE"] = str(self.capture)
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--codex-bin",
                str(self.fake_codex),
                "--cwd",
                str(self.root),
                *args,
            ],
            input=prompt,
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )

    def test_tier_dry_runs_include_explicit_model_and_effort(self) -> None:
        expected = {
            "fast": ("gpt-5.6-luna", "low"),
            "standard": ("gpt-5.6-terra", "medium"),
            "deep": ("gpt-5.6-sol", "xhigh"),
            "review": ("gpt-5.6-sol", "max"),
        }
        for tier, (model, effort) in expected.items():
            with self.subTest(tier=tier):
                completed = self.run_router("--tier", tier, "--dry-run")
                self.assertEqual(completed.returncode, 0, completed.stderr)
                payload = json.loads(completed.stdout)
                self.assertEqual(payload["model"], model)
                self.assertEqual(payload["reasoning_effort"], effort)
                self.assertIn("--model", payload["command"])
                self.assertIn(model, payload["command"])
                self.assertIn(f'model_reasoning_effort="{effort}"', payload["command"])

    def test_explicit_override_and_prompt_are_passed_without_shell(self) -> None:
        prompt = "Inspect $(touch SHOULD_NOT_EXIST); `uname`; $HOME"
        completed = self.run_router(
            "--tier",
            "fast",
            "--model",
            "gpt-5.4-mini",
            "--reasoning-effort",
            "high",
            prompt=prompt,
        )
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stdout.strip(), "WORKER_OK")
        captured = json.loads(self.capture.read_text(encoding="utf-8"))
        self.assertIn("gpt-5.4-mini", captured["argv"])
        self.assertIn(prompt, captured["stdin"])
        self.assertFalse((self.root / "SHOULD_NOT_EXIST").exists())

    def test_unavailable_model_fails_instead_of_inheriting(self) -> None:
        completed = self.run_router("--model", "not-a-model")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("not picker-visible", completed.stderr)

    def test_policy_is_native_first_and_cli_luna_is_explicit(self) -> None:
        skill = SKILL.read_text(encoding="utf-8")
        policy = POLICY.read_text(encoding="utf-8")
        self.assertIn("Default to the native backend", skill)
        self.assertIn("CLI Luna is an exception", skill)
        self.assertIn("| `fast` | native | `gpt-5.6-terra` | `low` |", policy)
        self.assertIn("CLI Luna is explicit/exceptional", policy)
        self.assertNotIn("normal route for isolated `fast` scans on Luna", skill)

    def test_workspace_write_requires_acknowledgement(self) -> None:
        completed = self.run_router("--sandbox", "workspace-write")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("requires --allow-write", completed.stderr)

    def test_ultra_is_rejected_for_leaf_workers(self) -> None:
        completed = self.run_router("--reasoning-effort", "ultra")
        self.assertEqual(completed.returncode, 2)
        self.assertIn("not allowed for bounded CLI leaf workers", completed.stderr)

    def test_leaf_worker_disables_nested_agents(self) -> None:
        completed = self.run_router("--tier", "fast")
        self.assertEqual(completed.returncode, 0, completed.stderr)
        captured = json.loads(self.capture.read_text(encoding="utf-8"))
        argv = captured["argv"]
        self.assertIn("multi_agent", argv)
        self.assertIn("multi_agent_v2", argv)
        self.assertIn("Do not spawn", captured["stdin"])


if __name__ == "__main__":
    unittest.main()
