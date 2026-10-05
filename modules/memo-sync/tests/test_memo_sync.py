"""Exercise the CLI with local snapshots; never connect to or write Apple Notes."""

from dataclasses import asdict, replace
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


MODULE = Path(__file__).resolve().parents[1]
SCRIPT = MODULE / "files/memo_sync.py"
spec = importlib.util.spec_from_file_location("memo_sync", SCRIPT)
memo = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = memo
spec.loader.exec_module(memo)


class MemoSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="memo-sync-test-")
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.root = self.directory / "memo"
        self.fixtures = self.directory / "snapshots"
        self.fixtures.mkdir()
        self.note = memo.Note(
            id="synthetic-note-1", title="Synthetic 日本語メモ",
            html="<div>Title</div>" + "".join(f"<p>KEEP_{i}</p>" for i in range(7)),
            text="Synthetic 日本語メモ\n\n" + "\n".join(f"KEEP_{i}" for i in range(7)),
            modified="2026-10-05T00:00:00Z",
        )
        self.source = memo.FixtureNotes(self.fixtures)
        self.workspace = memo.Workspace(self.root, self.source)
        self.remote(self.note)

    def remote(self, note):
        text = json.dumps(asdict(note), ensure_ascii=False)
        (self.fixtures / "selected.json").write_text(text)
        (self.fixtures / (memo.digest(note.id) + ".json")).write_text(text)

    def cli(self, *args, success=True):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--root", str(self.root),
             "--fixture-dir", str(self.fixtures), *args],
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode == 0, success, result.stderr)
        return result

    def test_registration_preserves_all_text_and_original_html(self):
        result = self.cli("register")
        path = Path(result.stdout.strip())
        self.assertEqual(path.read_text(), memo.file_text(self.note.text))
        snapshots = list((self.root / ".memo-sync/history").glob("*/*.json"))
        self.assertEqual(len(snapshots), 1)
        self.assertEqual(json.loads(snapshots[0].read_text())["html"], self.note.html)
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.root / ".memo-sync").stat().st_mode & 0o777, 0o700)
        result = json.loads(self.cli("status", "--json").stdout)
        self.assertEqual(result[0]["status"], "in_sync")
        self.assertFalse(result[0]["writes_enabled"])

    def test_existing_file_is_never_overwritten(self):
        self.root.mkdir()
        existing = self.root / (self.note.title + ".md")
        existing.write_text("Unrelated existing file")
        path = self.workspace.register()
        self.assertNotEqual(path, existing)
        self.assertEqual(existing.read_text(), "Unrelated existing file")

    def test_reregister_preserves_local_edits(self):
        path = self.workspace.register()
        path.write_text("Unsynced local edits")
        self.assertEqual(self.workspace.register(), path)
        self.assertEqual(path.read_text(), "Unsynced local edits")

    def test_local_changes_are_pending_and_never_write_remote(self):
        path = self.workspace.register()
        before = (self.fixtures / (memo.digest(self.note.id) + ".json")).read_bytes()
        path.write_text("Local edited text\n")
        result = self.workspace.inspect()[0]
        self.assertEqual(result["status"], "push_pending")
        self.assertTrue(result["local_diff"])
        self.assertEqual(before, (self.fixtures / (memo.digest(self.note.id) + ".json")).read_bytes())
        self.assertEqual(path.read_text(), "Local edited text\n")

    def test_remote_changes_are_pending_and_never_overwrite_file(self):
        path = self.workspace.register()
        before = path.read_bytes()
        updated = replace(self.note, text="Remote edited text", html="<p>Remote edited text</p>")
        self.remote(updated)
        result = self.workspace.inspect()[0]
        self.assertEqual(result["status"], "pull_pending")
        self.assertTrue(result["remote_diff"])
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual(len(list((self.root / ".memo-sync/history").glob("*/*.json"))), 2)

    def test_conflict_preserves_both_sides(self):
        path = self.workspace.register()
        path.write_text("Local edits\n")
        updated = replace(self.note, text="Remote edits", html="<p>Remote edits</p>")
        self.remote(updated)
        self.assertEqual(self.workspace.inspect()[0]["status"], "conflict")
        self.assertEqual(path.read_text(), "Local edits\n")
        self.assertEqual(self.source.read(self.note.id).text, "Remote edits")

    def test_deletions_are_not_propagated(self):
        path = self.workspace.register()
        path.unlink()
        self.assertEqual(self.workspace.inspect()[0]["status"], "local_missing")
        self.assertIsNotNone(self.source.read(self.note.id))
        path.write_text("Keep local text")
        (self.fixtures / (memo.digest(self.note.id) + ".json")).unlink()
        self.assertEqual(self.workspace.inspect()[0]["status"], "remote_missing")
        self.assertEqual(path.read_text(), "Keep local text")

    def test_timestamp_only_change_does_not_create_false_conflict(self):
        self.workspace.register()
        self.remote(replace(self.note, modified="2026-10-05T01:00:00Z"))
        self.assertEqual(self.workspace.inspect()[0]["status"], "in_sync")

    def test_formatting_change_and_converged_edits_are_distinct(self):
        path = self.workspace.register()
        self.remote(replace(self.note, html="<div><b>changed style</b></div>"))
        self.assertEqual(self.workspace.inspect()[0]["status"], "format_changed")
        self.remote(replace(self.note, text="Same edited text", html="<p>Same edited text</p>"))
        path.write_text("Same edited text\n")
        self.assertEqual(self.workspace.inspect()[0]["status"], "converged")

    def test_snapshot_failure_prevents_editable_file_creation(self):
        self.workspace.prepare()
        (self.root / ".memo-sync/history" / memo.digest(self.note.id)).symlink_to(self.fixtures)
        with self.assertRaises(ValueError):
            self.workspace.register()
        self.assertEqual(list(self.root.glob("*.md")), [])

    def test_symlinked_note_and_metadata_are_rejected(self):
        path = self.workspace.register()
        outside = self.directory / "outside.txt"
        outside.write_text("Private outside file")
        path.unlink()
        path.symlink_to(outside)
        with self.assertRaises(OSError):
            self.workspace.inspect()
        self.assertEqual(outside.read_text(), "Private outside file")
        state = self.root / ".memo-sync/state.json"
        state.unlink()
        state.symlink_to(outside)
        with self.assertRaises(OSError):
            self.workspace.register()

    def test_tampered_baseline_does_not_read_outside_workspace(self):
        self.workspace.register()
        state = self.workspace.state()
        state["notes"][self.note.id]["base"] = "../../outside.txt"
        (self.root / ".memo-sync/state.json").write_text(json.dumps(state))
        with self.assertRaises(ValueError):
            self.workspace.inspect()

    def test_nonblocking_lock_prevents_concurrent_registration(self):
        self.workspace.prepare()
        with (self.root / ".memo-sync/lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.cli("register", success=False)
        self.assertEqual(list(self.root.glob("*.md")), [])

    def test_invalid_id_and_schema_stop_without_creating_files(self):
        malformed = asdict(self.note)
        malformed["text"] = None
        (self.fixtures / "selected.json").write_text(json.dumps(malformed))
        self.cli("register", success=False)
        self.assertEqual(list(self.root.glob("*.md")), [])
        self.remote(self.note)
        self.workspace.register()
        malformed = asdict(self.note)
        malformed["id"] = "a-different-note"
        (self.fixtures / (memo.digest(self.note.id) + ".json")).write_text(json.dumps(malformed))
        self.cli("status", success=False)

    def test_long_unicode_title_is_a_valid_filename(self):
        self.remote(replace(self.note, title="あ" * 200))
        path = self.workspace.register()
        self.assertLess(len(path.name.encode()), 255)
        self.assertEqual(path.read_text(), memo.file_text(self.note.text))

    def test_empty_json_status_remains_valid_json(self):
        self.assertEqual(json.loads(self.cli("status", "--json").stdout), [])

    def test_an_editor_save_during_notes_read_is_reported(self):
        path = self.workspace.register()
        original_read = self.source.read

        def save_during_read(note_id):
            path.write_text("A late editor save\n")
            return original_read(note_id)

        self.source.read = save_during_read
        result = self.workspace.inspect()[0]
        self.assertEqual(result["status"], "push_pending")
        self.assertTrue(any("late editor save" in line for line in result["local_diff"]))
        self.assertEqual(path.read_text(), "A late editor save\n")

    def test_attachments_are_flagged_and_source_stays_read_only(self):
        self.remote(replace(self.note, attachments=2, shared=True))
        self.workspace.register()
        result = self.workspace.inspect()[0]
        self.assertEqual(result["attachments"], 2)
        self.assertTrue(result["shared"])
        self.assertFalse(result["writes_enabled"])


if __name__ == "__main__":
    unittest.main()
