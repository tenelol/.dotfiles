import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
SCRIPT = REPOSITORY / "config/scripts/sync-vault-context-runtime"


class SyncVaultContextRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.bundle = self.root / "bundle"
        self.runtime_parent = self.root / "runtime"
        (self.bundle / "src").mkdir(parents=True)
        (self.bundle / "node_modules").mkdir()
        (self.bundle / "src/server.mjs").write_text(
            'if (process.argv.includes("--self-test")) process.exit(0);\n',
            encoding="utf-8",
        )
        (self.bundle / "node_modules/fixture.txt").write_text(
            "fixture\n",
            encoding="utf-8",
        )
        os.chmod(self.bundle / "src/server.mjs", 0o444)
        os.chmod(self.bundle / "src", 0o555)
        os.chmod(self.bundle / "node_modules/fixture.txt", 0o444)
        os.chmod(self.bundle / "node_modules", 0o555)
        os.chmod(self.bundle, 0o555)

    def tearDown(self):
        for path in sorted(self.bundle.rglob("*"), reverse=True):
            if path.is_dir():
                os.chmod(path, 0o755)
            elif not path.is_symlink():
                os.chmod(path, 0o644)
        os.chmod(self.bundle, 0o755)
        self.temporary_directory.cleanup()

    def run_script(self, *arguments):
        environment = os.environ.copy()
        environment.update(
            {
                "VAULT_CONTEXT_BUNDLE": str(self.bundle),
                "VAULT_CONTEXT_RUNTIME_PARENT": str(self.runtime_parent),
            }
        )
        return subprocess.run(
            [str(SCRIPT), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=environment,
        )

    def test_read_only_bundle_is_deployed_as_writable_runtime(self):
        first = self.run_script()
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertIn("runtime synchronized", first.stdout)

        destination = self.runtime_parent / "vault-context-mcp"
        self.assertTrue(destination.is_dir())
        self.assertTrue(destination.stat().st_mode & stat.S_IWUSR)
        self.assertTrue(
            (destination / "src/server.mjs").stat().st_mode & stat.S_IWUSR
        )
        self.assertEqual(
            list(self.runtime_parent.glob(".vault-context-mcp-stage.*")),
            [],
        )

        second = self.run_script()
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertIn("already current", second.stdout)
        self.assertEqual(
            list(self.runtime_parent.glob(".vault-context-mcp-stage.*")),
            [],
        )

        check = self.run_script("--check")
        self.assertEqual(check.returncode, 0, check.stderr)
        self.assertIn("runtime is current", check.stdout)

    def test_check_detects_content_drift_and_sync_repairs_it(self):
        self.assertEqual(self.run_script().returncode, 0)
        destination_server = (
            self.runtime_parent / "vault-context-mcp/src/server.mjs"
        )
        destination_server.write_text("process.exit(1);\n", encoding="utf-8")

        drift = self.run_script("--check")
        self.assertNotEqual(drift.returncode, 0)
        self.assertIn("differs", drift.stderr)

        repair = self.run_script()
        self.assertEqual(repair.returncode, 0, repair.stderr)
        self.assertEqual(
            destination_server.read_text(encoding="utf-8"),
            'if (process.argv.includes("--self-test")) process.exit(0);\n',
        )

    def test_large_drift_is_not_misclassified_as_current(self):
        self.assertEqual(self.run_script().returncode, 0)
        os.chmod(self.bundle, 0o755)
        os.chmod(self.bundle / "node_modules", 0o755)
        for index in range(2500):
            (self.bundle / "node_modules" / f"fixture-{index:04d}.txt").write_text(
                f"{index}\n",
                encoding="utf-8",
            )
        os.chmod(self.bundle / "node_modules", 0o555)
        os.chmod(self.bundle, 0o555)

        update = self.run_script()

        self.assertEqual(update.returncode, 0, update.stderr)
        self.assertIn("runtime synchronized", update.stdout)
        self.assertTrue(
            (
                self.runtime_parent
                / "vault-context-mcp/node_modules/fixture-2499.txt"
            ).is_file()
        )


if __name__ == "__main__":
    unittest.main()
