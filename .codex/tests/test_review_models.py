"""Verify both CLI review paths without starting a model or contacting GitHub."""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]


def load_reviewer(name, filename):
    path = ROOT / ".agents/skills" / name / "scripts" / filename
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


REVIEWERS = [
    load_reviewer("codex-plan-review-loop", "plan_review.py"),
    load_reviewer("codex-pr-review-loop", "pr_review.py"),
]


class ReviewModelTests(unittest.TestCase):
    def test_actual_fresh_and_resumed_commands_use_defaults_and_disable_children(self):
        for module in REVIEWERS:
            for thread_id in (None, "existing-review"):
                with self.subTest(module=module.__name__, thread_id=thread_id):
                    with tempfile.TemporaryDirectory() as directory:
                        commands = []

                        def fake_cli(command, prompt, timeout, stdout_path, stderr_path):
                            commands.append(command)
                            Path(stdout_path).write_text("")
                            Path(command[command.index("-o") + 1]).write_text('{"findings": []}')
                            return 0

                        state = {"config": dict(module.DEFAULT_CONFIG), "threadId": thread_id}
                        with patch.object(module, "run_subprocess", side_effect=fake_cli):
                            result, _ = module.run_codex(state, directory, "Review only", "round1")
                        self.assertEqual(json.loads(result), {"findings": []})
                        self.assertEqual(len(commands), 1)
                        command = commands[0]
                        self.assertEqual(command[command.index("--model") + 1], "gpt-5.6-sol")
                        self.assertIn('model_reasoning_effort="xhigh"', command)
                        self.assertIn("agents.enabled=false", command)

    def test_partial_overrides_preserve_other_default_and_extra_options(self):
        for module in REVIEWERS:
            with self.subTest(module=module.__name__):
                args = module.codex_review_args(["--model=gpt-5.6-terra", "--skip-git-repo-check"])
                self.assertNotIn("gpt-5.6-sol", args)
                self.assertIn('model_reasoning_effort="xhigh"', args)
                self.assertIn("--skip-git-repo-check", args)
                args = module.codex_review_args(["-c", 'model_reasoning_effort="max"'])
                self.assertIn("gpt-5.6-sol", args)
                self.assertNotIn('model_reasoning_effort="xhigh"', args)

    def test_excluded_models_are_rejected_in_all_supported_spellings(self):
        for module in REVIEWERS:
            for args in (
                ["--model", "gpt-5.6-luna"], ["-mgpt-5.6-luna"],
                ["--model=gpt-5.6-luna"], ["-c", 'model="gpt-5.6-luna"'],
                ["--config=model='gpt-5.6-luna'"],
            ):
                with self.subTest(module=module.__name__, args=args):
                    with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                        module.codex_review_args(args)

    def test_config_without_model_args_still_receives_review_defaults(self):
        for module in REVIEWERS:
            with self.subTest(module=module.__name__), tempfile.TemporaryDirectory() as directory:
                config_path = Path(directory) / "review.json"
                config_path.write_text('{"codexExtraArgs": [], "maxRounds": 2}')
                config = module.load_config(str(config_path))
                self.assertEqual(config["maxRounds"], 2)
                self.assertFalse(config["requireHumanOnFirstRound"])
                self.assertFalse(config["requireHumanOnNewHighSeverity"])
                self.assertIn("gpt-5.6-sol", module.codex_review_args(config["codexExtraArgs"]))


if __name__ == "__main__":
    unittest.main()
