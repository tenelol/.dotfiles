#!/usr/bin/env python3

from __future__ import annotations

from contextlib import redirect_stdout
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


HOOK = Path(__file__).resolve().parents[1] / "enforce-worktree-layout.py"
SPEC = importlib.util.spec_from_file_location("enforce_worktree_layout", HOOK)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {HOOK}")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class WorktreeLayoutHookTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name) / "projects"
        self.repository = self.root / "sample"
        self.repository.mkdir(parents=True)
        subprocess.run(["git", "init", "--quiet", self.repository], check=True)

    def reason(self, command: str, cwd: Path | None = None) -> str | None:
        return MODULE.deny_reason_for_command(
            command,
            cwd or self.repository,
            projects_root=self.root,
        )

    def test_allows_repo_grouped_add(self) -> None:
        target = self.root / ".worktrees" / "sample" / "feature-a"
        self.assertIsNone(self.reason(f"git worktree add {target}"))

    def test_allows_repo_grouped_add_with_git_c_and_branch_option(self) -> None:
        target = self.root / ".worktrees" / "sample" / "feature-b"
        command = f"git -C {self.repository} worktree add -b feat/example {target} HEAD"
        self.assertIsNone(self.reason(command, self.root))

    def test_denies_top_level_projects_destination(self) -> None:
        reason = self.reason(f"git worktree add {self.root / 'sample-feature'}")
        self.assertIn("/.worktrees/sample/<worktree>", reason or "")

    def test_denies_singular_project_destination(self) -> None:
        reason = self.reason("git worktree add ~/project/sample-feature")
        self.assertIn("worktree destination must be", reason or "")

    def test_denies_flat_worktrees_destination(self) -> None:
        reason = self.reason(f"git worktree add {self.root / '.worktrees' / 'feature'}")
        self.assertIn("/.worktrees/sample/<worktree>", reason or "")

    def test_validates_move_destination(self) -> None:
        source = self.root / ".worktrees" / "sample" / "old"
        valid = self.root / ".worktrees" / "sample" / "new"
        invalid = self.root / "new"
        self.assertIsNone(self.reason(f"git worktree move {source} {valid}"))
        self.assertIn("worktree destination must be", self.reason(f"git worktree move {source} {invalid}") or "")

    def test_denies_noncanonical_repository(self) -> None:
        nested = self.root / "nested" / "sample"
        nested.mkdir(parents=True)
        subprocess.run(["git", "init", "--quiet", nested], check=True)
        target = self.root / ".worktrees" / "sample" / "feature"
        reason = self.reason(f"git worktree add {target}", nested)
        self.assertIn("canonical repository must be", reason or "")

    def test_allows_irrelevant_git_and_shell_commands(self) -> None:
        self.assertIsNone(self.reason("git status --short && rg worktree AGENTS.md"))
        self.assertIsNone(self.reason(f"echo git worktree add {self.root / 'bad'}"))

    def test_denies_inline_shell_mutation(self) -> None:
        target = self.root / "bad"
        reason = self.reason(f"bash -lc 'git worktree add {target}'")
        self.assertIn("worktree destination must be", reason or "")

    def test_denies_exec_and_builtin_wrapper_bypasses(self) -> None:
        target = self.root / "bad"
        self.assertIn(
            "worktree destination must be",
            self.reason(f"exec git worktree add {target}") or "",
        )
        self.assertIn(
            "worktree destination must be",
            self.reason(f"bash -lc 'exec git worktree add {target}'") or "",
        )
        other = self.root / "other"
        other.mkdir()
        subprocess.run(["git", "init", "--quiet", other], check=True)
        command = f"builtin export GIT_DIR={other / '.git'}; git worktree add {target}"
        self.assertIn("must not override", self.reason(command) or "")
        self.assertIn(
            "worktree destination must be",
            self.reason(f"time git worktree add {target}") or "",
        )
        self.assertIn(
            "worktree destination must be",
            self.reason(f"if git worktree add {target}") or "",
        )
        sudo_assignment = f"sudo GIT_DIR={other / '.git'} git worktree add {target}"
        self.assertIn("must not override", self.reason(sudo_assignment) or "")

    def test_denies_persistent_and_temporary_git_alias_mutation(self) -> None:
        target = self.root / "bad"
        subprocess.run(
            ["git", "-C", self.repository, "config", "alias.wa", "worktree add"],
            check=True,
        )
        self.assertIn("worktree destination must be", self.reason(f"git wa {target}") or "")
        command = f"git -c 'alias.wm=worktree move' wm source {target}"
        self.assertIn("worktree destination must be", self.reason(command) or "")

    def test_compound_cd_requires_explicit_git_context(self) -> None:
        other = self.root / "other"
        other.mkdir()
        subprocess.run(["git", "init", "--quiet", other], check=True)
        wrong_group = self.root / ".worktrees" / "sample" / "feature"
        reason = self.reason(f"cd {other} && git worktree add {wrong_group}")
        self.assertIn("must use an absolute git -C", reason or "")

        correct_group = self.root / ".worktrees" / "other" / "feature"
        command = f"cd {other} && git -C {other} worktree add {correct_group}"
        self.assertIsNone(self.reason(command))

        relative_context = f"cd {other} && git -C . worktree add {wrong_group}"
        self.assertIn("must use an absolute git -C", self.reason(relative_context) or "")

    def test_environment_chdir_requires_absolute_git_context(self) -> None:
        other = self.root / "other"
        other.mkdir()
        subprocess.run(["git", "init", "--quiet", other], check=True)
        wrong_group = self.root / ".worktrees" / "sample" / "feature"
        reason = self.reason(f"env -C {other} git worktree add {wrong_group}")
        self.assertIn("must use an absolute git -C", reason or "")

        correct_group = self.root / ".worktrees" / "other" / "feature"
        command = f"env -C {other} git -C {other} worktree add {correct_group}"
        self.assertIsNone(self.reason(command))

    def test_denies_git_repository_and_alias_environment_overrides(self) -> None:
        other = self.root / "other"
        other.mkdir()
        subprocess.run(["git", "init", "--quiet", other], check=True)
        wrong_group = self.root / ".worktrees" / "sample" / "feature"
        git_dir_command = f"GIT_DIR={other / '.git'} git worktree add {wrong_group}"
        self.assertIn("must not override", self.reason(git_dir_command) or "")

        alias_command = (
            "env GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.wa "
            f"GIT_CONFIG_VALUE_0='worktree add' git wa {wrong_group}"
        )
        self.assertIn("cannot safely resolve git subcommand", self.reason(alias_command) or "")

        subprocess.run(
            ["git", "-C", other, "config", "alias.wa", "worktree add"],
            check=True,
        )
        repository_alias = f"GIT_DIR={other / '.git'} git wa {wrong_group}"
        self.assertIn("cannot safely resolve git subcommand", self.reason(repository_alias) or "")
        git_dir_alias = f"git --git-dir={other / '.git'} wa {wrong_group}"
        self.assertIn("cannot safely resolve git subcommand", self.reason(git_dir_alias) or "")

        included_alias = f"git -c include.path={other / '.git' / 'config'} wa {wrong_group}"
        self.assertIn("cannot safely resolve git subcommand", self.reason(included_alias) or "")
        config_env_alias = f"git --config-env=include.path=REPO_CONFIG wa {wrong_group}"
        self.assertIn("cannot safely resolve git subcommand", self.reason(config_env_alias) or "")
        direct_config_env_alias = f"git --config-env=alias.wa=WORKTREE_ALIAS wa {wrong_group}"
        self.assertIn("cannot safely resolve git subcommand", self.reason(direct_config_env_alias) or "")

    def test_denies_env_split_string_mutation(self) -> None:
        target = self.root / "bad"
        self.assertIn(
            "worktree destination must be",
            self.reason(f"env -S 'git worktree add {target}'") or "",
        )
        self.assertIn(
            "worktree destination must be",
            self.reason(f"env '--split-string=git worktree add {target}'") or "",
        )

    def test_persistent_environment_changes_taint_following_mutation(self) -> None:
        other = self.root / "other"
        other.mkdir()
        subprocess.run(["git", "init", "--quiet", other], check=True)
        wrong_group = self.root / ".worktrees" / "sample" / "feature"
        exported = f"export GIT_DIR={other / '.git'}; git worktree add {wrong_group}"
        self.assertIn("must not override", self.reason(exported) or "")
        unset = f"unset GIT_DIR; git worktree add {wrong_group}"
        self.assertIn("must not override", self.reason(unset) or "")
        sourced = f"source ./environment.sh; git worktree add {wrong_group}"
        self.assertIn("must not override", self.reason(sourced) or "")

    def test_main_emits_pretooluse_deny_contract(self) -> None:
        payload = {
            "hook_event_name": "PreToolUse",
            "tool_name": "Bash",
            "cwd": str(self.repository),
            "tool_input": {"command": f"git worktree add {self.root / 'bad'}"},
        }
        previous_stdin = sys.stdin
        output = io.StringIO()
        try:
            sys.stdin = io.StringIO(json.dumps(payload))
            with redirect_stdout(output):
                self.assertEqual(0, MODULE.main(projects_root=self.root))
        finally:
            sys.stdin = previous_stdin
        response = json.loads(output.getvalue())
        hook_output = response["hookSpecificOutput"]
        self.assertEqual("PreToolUse", hook_output["hookEventName"])
        self.assertEqual("deny", hook_output["permissionDecision"])

    def test_main_ignores_malformed_or_unrelated_input(self) -> None:
        for raw in ("not-json", json.dumps({"hook_event_name": "Stop"})):
            previous_stdin = sys.stdin
            output = io.StringIO()
            try:
                sys.stdin = io.StringIO(raw)
                with redirect_stdout(output):
                    self.assertEqual(0, MODULE.main(projects_root=self.root))
            finally:
                sys.stdin = previous_stdin
            self.assertEqual("", output.getvalue())


if __name__ == "__main__":
    unittest.main()
