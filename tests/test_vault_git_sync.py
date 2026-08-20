import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(os.environ.get("DOTFILES_REPOSITORY", Path(__file__).resolve().parents[1]))
SCRIPT = ROOT / "config" / "scripts" / "vault-git-sync"


def run(*args: str, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, check=check, text=True, capture_output=True)


class VaultGitSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = Path(tempfile.mkdtemp(prefix="vault-git-sync-test-"))
        self.remote = self.temp / "remote.git"
        self.vault = self.temp / "vault"
        run("git", "init", "--bare", "--initial-branch=main", str(self.remote), cwd=self.temp)
        run("git", "init", "--initial-branch=main", str(self.vault), cwd=self.temp)
        run("git", "config", "user.name", "Vault Test", cwd=self.vault)
        run("git", "config", "user.email", "vault@example.invalid", cwd=self.vault)
        run("git", "remote", "add", "origin", str(self.remote), cwd=self.vault)
        (self.vault / ".gitignore").write_text(".vault-context/\n", encoding="utf-8")
        records = self.vault / "10 Records" / "note"
        records.mkdir(parents=True)
        (records / "seed.md").write_text("# Seed\n", encoding="utf-8")
        run("git", "add", ".gitignore", "10 Records", cwd=self.vault)
        run("git", "commit", "-m", "seed", cwd=self.vault)
        run("git", "push", "-u", "origin", "main", cwd=self.vault)

        self.cli = self.temp / "fake-vault-context"
        self.write_cli()
        self.scanner = self.temp / "check-sensitive-stdin.mjs"
        self.scanner.write_text(
            "let input = '';\n"
            "process.stdin.setEncoding('utf8');\n"
            "process.stdin.on('data', chunk => { input += chunk; });\n"
            "process.stdin.on('end', () => {\n"
            "  if (/(?:api[_-]?key|secret|password|token)\\s*[:=]\\s*\\S+/i.test(input)) process.exit(1);\n"
            "});\n",
            encoding="utf-8",
        )
        self.env = {
            **os.environ,
            "VAULT_GIT_SYNC_ROOT": str(self.vault),
            "VAULT_CONTEXT_CLI": str(self.cli),
            "VAULT_CONTEXT_SECRET_SCANNER": str(self.scanner),
            "VAULT_GIT_EXPECTED_REMOTE": str(self.remote),
        }

    def tearDown(self) -> None:
        shutil.rmtree(self.temp)

    def write_cli(self, *, failures: dict[str, int] | None = None) -> None:
        summary = {
            "raw_integrity_failures": 0,
            "sensitive_quarantined": 0,
            "noncanonical_quarantined": 0,
            "schema_violations": 0,
            "broken_links": 0,
            "missing_summary": 0,
            "missing_scope_or_project": 0,
        }
        summary.update(failures or {})
        self.cli.write_text(
            "#!/usr/bin/env bash\n"
            "if [[ \"$1\" == \"reindex\" ]]; then echo '{\"ok\":true}'; exit 0; fi\n"
            "if [[ -n \"${VAULT_TEST_MUTATE_DURING_QUALITY:-}\" ]]; then\n"
            "  printf '# changed during quality\\n' >> \"${VAULT_TEST_MUTATE_DURING_QUALITY}\"\n"
            "fi\n"
            "if [[ -n \"${VAULT_TEST_STAGE_DURING_QUALITY:-}\" ]]; then\n"
            "  printf '# staged during quality\\n' >> \"${VAULT_TEST_STAGE_DURING_QUALITY}\"\n"
            "  git -C \"${VAULT_GIT_SYNC_ROOT}\" add -- \"${VAULT_TEST_STAGE_DURING_QUALITY}\"\n"
            "fi\n"
            "cat <<'JSON'\n"
            + json.dumps(
                {"summary": summary}
            )
            + "\nJSON\n",
            encoding="utf-8",
        )
        self.cli.chmod(0o755)

    def sync(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(SCRIPT)],
            cwd=self.vault,
            env=self.env,
            text=True,
            capture_output=True,
        )

    def test_noop(self) -> None:
        result = self.sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "noop")

    def test_only_allowlisted_content_is_pushed(self) -> None:
        allowed = self.vault / "10 Records" / "note" / "new.md"
        outside = self.vault / "outside.md"
        allowed.write_text("# New\n", encoding="utf-8")
        outside.write_text("# Outside\n", encoding="utf-8")
        result = self.sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["status"], "committed_and_pushed")
        self.assertIn("outside.md", run("git", "status", "--short", cwd=self.vault).stdout)
        self.assertEqual(
            run("git", "--git-dir", str(self.remote), "show", "main:10 Records/note/new.md", cwd=self.temp).stdout,
            "# New\n",
        )

    def test_quality_failure_leaves_index_and_head_unchanged(self) -> None:
        self.write_cli(
            failures={
                "raw_integrity_failures": 1,
                "noncanonical_quarantined": 2,
            }
        )
        path = self.vault / "10 Records" / "note" / "invalid.md"
        path.write_text("# Invalid\n", encoding="utf-8")
        before = run("git", "rev-parse", "HEAD", cwd=self.vault).stdout
        result = self.sync()
        self.assertNotEqual(result.returncode, 0)
        output = json.loads(result.stdout)
        self.assertEqual(output["reason"], "quality_gate_failed")
        self.assertEqual(
            output["failed_checks"],
            [
                {"check": "raw_integrity_failures", "count": 1},
                {"check": "noncanonical_quarantined", "count": 2},
            ],
        )
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.vault).stdout, before)
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")

    def test_secret_failure_unstages_without_committing(self) -> None:
        path = self.vault / "10 Records" / "note" / "secret.md"
        path.write_text("api_key=FAKE_SECRET_VALUE_1234567890\n", encoding="utf-8")
        before = run("git", "rev-parse", "HEAD", cwd=self.vault).stdout
        result = self.sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["reason"], "staged_secret_suspected")
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.vault).stdout, before)
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")

    def test_binary_secret_failure_scans_the_staged_blob(self) -> None:
        system = self.vault / "90 System"
        system.mkdir()
        path = system / "secret.txt"
        path.write_bytes(b"\0api_key=FAKE_BINARY_SECRET_1234567890\n")
        before = run("git", "rev-parse", "HEAD", cwd=self.vault).stdout

        result = self.sync()

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["reason"], "staged_secret_suspected")
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.vault).stdout, before)
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")

    def test_tracked_raw_modification_is_rejected(self) -> None:
        raw = self.vault / "00 Inbox" / "raw"
        raw.mkdir(parents=True)
        path = raw / "2026-07-23T000000Z-seed.md"
        path.write_text("# Raw\n\noriginal\n", encoding="utf-8")
        run("git", "add", str(path.relative_to(self.vault)), cwd=self.vault)
        run("git", "commit", "-m", "add raw", cwd=self.vault)
        run("git", "push", cwd=self.vault)
        before = run("git", "rev-parse", "HEAD", cwd=self.vault).stdout
        path.write_text("# Raw\n\nchanged\n", encoding="utf-8")

        result = self.sync()

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["reason"], "immutable_raw_changed")
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.vault).stdout, before)
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")

    def test_tracked_raw_deletion_is_rejected(self) -> None:
        raw = self.vault / "00 Inbox" / "raw"
        raw.mkdir(parents=True)
        path = raw / "2026-07-23T000000Z-seed.md"
        path.write_text("# Raw\n\noriginal\n", encoding="utf-8")
        relative_path = str(path.relative_to(self.vault))
        run("git", "add", relative_path, cwd=self.vault)
        run("git", "commit", "-m", "add raw", cwd=self.vault)
        run("git", "push", cwd=self.vault)
        before = run("git", "rev-parse", "HEAD", cwd=self.vault).stdout
        path.unlink()

        result = self.sync()

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["reason"], "immutable_raw_changed")
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.vault).stdout, before)
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")
        self.assertEqual(
            run(
                "git",
                "--git-dir",
                str(self.remote),
                "show",
                f"main:{relative_path}",
                cwd=self.temp,
            ).stdout,
            "# Raw\n\noriginal\n",
        )

    def test_remote_divergence_blocks_before_staging(self) -> None:
        peer = self.temp / "peer"
        run("git", "clone", str(self.remote), str(peer), cwd=self.temp)
        run("git", "config", "user.name", "Peer", cwd=peer)
        run("git", "config", "user.email", "peer@example.invalid", cwd=peer)
        (peer / "remote.md").write_text("# Remote\n", encoding="utf-8")
        run("git", "add", "remote.md", cwd=peer)
        run("git", "commit", "-m", "remote", cwd=peer)
        run("git", "push", cwd=peer)
        (self.vault / "10 Records" / "note" / "local.md").write_text("# Local\n", encoding="utf-8")
        result = self.sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout)["reason"], "remote_diverged")
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")

    def test_worktree_change_during_quality_is_not_committed(self) -> None:
        path = self.vault / "10 Records" / "note" / "raced.md"
        path.write_text("# Before\n", encoding="utf-8")
        before = run("git", "rev-parse", "HEAD", cwd=self.vault).stdout
        self.env["VAULT_TEST_MUTATE_DURING_QUALITY"] = str(path)

        result = self.sync()

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(
            json.loads(result.stdout)["reason"],
            "vault_changed_during_validation",
        )
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.vault).stdout, before)
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")
        self.assertNotEqual(
            run(
                "git",
                "--git-dir",
                str(self.remote),
                "cat-file",
                "-e",
                "main:10 Records/note/raced.md",
                cwd=self.temp,
                check=False,
            ).returncode,
            0,
        )

    def test_index_change_during_quality_is_not_committed(self) -> None:
        path = self.vault / "10 Records" / "note" / "restaged.md"
        path.write_text("# Before\n", encoding="utf-8")
        before = run("git", "rev-parse", "HEAD", cwd=self.vault).stdout
        self.env["VAULT_TEST_STAGE_DURING_QUALITY"] = str(path)

        result = self.sync()

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(
            json.loads(result.stdout)["reason"],
            "index_changed_during_validation",
        )
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.vault).stdout, before)
        self.assertEqual(run("git", "diff", "--cached", "--name-only", cwd=self.vault).stdout, "")

    def test_failed_push_is_retried_only_with_pending_marker(self) -> None:
        hooks = self.vault / ".git" / "hooks"
        pre_push = hooks / "pre-push"
        pre_push.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
        pre_push.chmod(0o755)
        (self.vault / "10 Records" / "note" / "pending.md").write_text("# Pending\n", encoding="utf-8")
        first = self.sync()
        self.assertNotEqual(first.returncode, 0)
        self.assertEqual(json.loads(first.stdout)["status"], "push_pending")
        self.assertTrue((self.vault / ".vault-context" / "pending-push").is_file())
        pre_push.unlink()
        second = self.sync()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(json.loads(second.stdout)["status"], "pushed_pending")
        self.assertFalse((self.vault / ".vault-context" / "pending-push").exists())


if __name__ == "__main__":
    unittest.main()
