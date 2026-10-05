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
from unittest.mock import patch


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


class BidirectionalTests(unittest.TestCase):
    # Reuse the existing offline workspace; every operation crosses the production interface.
    remote = MemoSyncTests.remote
    cli = MemoSyncTests.cli

    def setUp(self):
        MemoSyncTests.setUp(self)
        self.note = replace(self.note, html="<div>Synthetic 日本語メモ</div><div>KEEP_1</div>",
                            text="Synthetic 日本語メモ\nKEEP_1\n")
        self.remote(self.note)
        self.path = self.workspace.register(sync=True)

    def test_full_roundtrip_and_baseline_advances(self):
        text = "Synthetic 日本語メモ\n  <tag> & 日本語 🌱   \t\n\nKEEP_7\n\n"
        self.path.write_text(text)
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.assertEqual(self.source.read(self.note.id).text, text)
        self.assertEqual(self.path.read_text(), text)
        first = self.source.read(self.note.id)
        remote = replace(first, text=text + "REMOTE_EDIT\n", html=memo.render_text(first, text + "REMOTE_EDIT\n"))
        self.remote(remote)
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.assertEqual(self.path.read_text(), remote.text)
        self.assertEqual(self.workspace.inspect()[0]["status"], "in_sync")
        backups = (self.root / ".memo-sync/local-history")
        self.assertEqual((backups / (memo.digest(text) + ".txt")).read_text(), text)
        self.assertEqual(self.workspace.base(self.workspace.state()["notes"][self.note.id]).text, remote.text)
        self.path.write_text(remote.text + "SECOND_LOCAL_EDIT\n")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.assertEqual(self.source.read(self.note.id).text, remote.text + "SECOND_LOCAL_EDIT\n")

    def test_sync_stops_for_conflict_deletion_and_unsupported_format(self):
        self.path.write_text("Local edits\n")
        remote = replace(self.note, text="Remote edits\n", html="<div>Remote edits</div>")
        self.remote(remote)
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "conflict")
        self.assertEqual(self.path.read_text(), "Local edits\n")
        self.assertEqual(self.source.read(self.note.id), remote)
        self.path.unlink()
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "local_missing")
        self.assertEqual(self.source.read(self.note.id), remote)
        self.remote(self.note)
        self.path.write_text(self.note.text)
        decorated = replace(self.note, html="<div>Synthetic 日本語メモ</div><div><b>KEEP_1</b></div>")
        self.remote(decorated)
        self.workspace.inspect(sync=True)
        self.path.write_text("Local edits\n")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "unsupported")
        self.assertEqual(self.source.read(self.note.id), decorated)
        for kwargs in ({"attachments": 1}, {"shared": True}):
            self.remote(replace(self.note, **kwargs))
            self.path.write_text(self.note.text)
            self.workspace.inspect(sync=True)
            self.path.write_text("Local edits\n")
            self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "unsupported")

    def test_readonly_registration_and_disable_never_sync(self):
        self.workspace.enable(self.path.name, False)
        self.path.write_text("Disabled edit\n")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "push_pending")
        self.assertEqual(self.source.read(self.note.id), self.note)
        self.cli("enable", self.path.name)
        self.cli("sync", self.path.name)
        self.assertEqual(self.source.read(self.note.id).text, "Disabled edit\n")
        self.cli("disable", self.path.name)
        self.assertFalse(self.workspace.inspect()[0]["writes_enabled"])

    def test_watch_requires_two_stable_observations(self):
        self.path.write_text("Stable edit\n")
        self.assertEqual(self.workspace.inspect(sync=True, stable=True)[0]["status"], "push_pending")
        self.path.write_text("Newer edit\n")
        self.assertEqual(self.workspace.inspect(sync=True, stable=True)[0]["status"], "push_pending")
        self.assertEqual(self.source.read(self.note.id), self.note)
        self.assertEqual(self.workspace.inspect(sync=True, stable=True)[0]["status"], "in_sync")
        self.assertEqual(self.source.read(self.note.id).text, "Newer edit\n")

    def test_remote_cas_rejects_late_changes_and_stays_stopped(self):
        self.path.write_text("Local edits\n")
        original = self.source.replace

        def change_before_write(expected, text):
            self.remote(replace(self.note, text="Late remote edit\n", html="<div>Late remote edit</div>"))
            return original(expected, text)

        self.source.replace = change_before_write
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "interrupted")
        self.assertEqual(self.source.read(self.note.id).text, "Late remote edit\n")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "interrupted")
        self.assertEqual(self.path.read_text(), "Local edits\n")
        self.assertTrue(self.workspace.state()["notes"][self.note.id]["pending"]["error"])

    def test_late_editor_save_is_retained_at_atomic_swap(self):
        remote = replace(self.note, text="Remote edit\n", html="<div>Remote edit</div>")
        self.remote(remote)
        original = memo.swap_file

        def save_during_swap(path, staging):
            # Neovim commonly saves by replacing the path with a new inode.
            replacement = path.with_suffix(".new")
            replacement.write_text("LATE_EDITOR_SAVE\n")
            os.replace(replacement, path)
            original(path, staging)

        with patch.object(memo, "swap_file", save_during_swap):
            self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "interrupted")
        displaced = list((self.root / ".memo-sync/local-history").glob("*-displaced.txt"))
        self.assertEqual(displaced[0].read_text(), "LATE_EDITOR_SAVE\n")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "interrupted")
        self.assertEqual(self.source.read(self.note.id), remote)

    def test_incorrect_readback_and_backup_failure_prevent_further_writes(self):
        self.path.write_text("Local edits\n")
        writes = []

        def truncated(expected, text):
            writes.append(text)
            note = replace(expected, text="Truncated\n", html="<div>Truncated</div>")
            self.remote(note)
            return note

        self.source.replace = truncated
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "interrupted")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "interrupted")
        self.assertEqual(len(writes), 1)
        self.assertEqual(self.path.read_text(), "Local edits\n")
        self.assertEqual((self.root / ".memo-sync/local-history" / (memo.digest("Local edits\n") + ".txt")).read_text(), "Local edits\n")
        self.path.write_text("Truncated\n")
        self.workspace.enable(self.path.name)
        self.assertEqual(self.workspace.inspect()[0]["status"], "in_sync")
        self.path.write_text("Another edit\n")
        original = memo.write_new

        def fail_backup(path, text):
            if path.parent.name == "local-history":
                raise OSError("Backup failed")
            return original(path, text)

        with patch.object(memo, "write_new", fail_backup):
            self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "unsupported")
        self.assertEqual(len(writes), 1)

    def test_completed_write_after_crash_can_be_verified_without_repeating_write(self):
        text = "Verified edit\n"
        self.path.write_text(text)
        state = self.workspace.state()
        record = state["notes"][self.note.id]
        record["pending"] = {"operation": "a" * 32, "direction": "push_pending",
                             "target": memo.digest(text), "local": memo.digest(text)}
        memo.atomic_json(self.root / ".memo-sync/state.json", state)
        self.remote(replace(self.note, text=text, html="<div>Verified edit</div>"))
        with patch.object(self.source, "replace", side_effect=AssertionError("Must not write again")):
            self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.assertNotIn("pending", self.workspace.state()["notes"][self.note.id])

    def test_html_validation_preserves_all_paragraphs_and_rejects_loss(self):
        for tag in ("p", "div"):
            text = "Title\n" + "".join(f"KEEP_{i}\n" for i in range(7))
            note = replace(self.note, html=f"<{tag}>Title</{tag}>" + "".join(
                f"<{tag}>KEEP_{i}</{tag}>" for i in range(7)), text=text)
            self.assertEqual(memo.text_style(note), "")
        heading = replace(self.note, html='<div><b><span style="font-size: 24px">Synthetic 日本語メモ</span></b></div><div>KEEP_1</div>')
        self.assertEqual(memo.text_style(heading), "h1")
        trailing_br = replace(self.note, html="<div>Synthetic 日本語メモ</div><div>KEEP_1<br></div>")
        self.assertEqual(memo.text_style(trailing_br), "")
        for invalid in (replace(self.note, text="Missing paragraphs\n"),
                        replace(self.note, html="<table><tr><td>KEEP</td></tr></table>"),
                        replace(self.note, html="<div>Synthetic <b>日本語メモ</b></div><div>KEEP_1</div>"),
                        replace(self.note, html='<div><a href="https://example.com">KEEP</a></div>')):
            with self.assertRaises(ValueError):
                memo.render_text(invalid, "New text\n")
        for invalid_text in ("", "   \n", "NUL\0"):
            with self.assertRaises(ValueError):
                memo.render_text(self.note, invalid_text)

    def test_missing_final_newline_is_not_an_endless_change(self):
        self.path.write_text("No final newline")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.assertEqual(self.path.read_text(), "No final newline")

    def test_import_all_enables_plain_notes_and_preserves_rich_notes(self):
        duplicate = replace(self.note, id="synthetic-note-2")
        rich = replace(self.note, id="synthetic-rich", title="Rich",
                       html="<div>Synthetic 日本語メモ</div><div><b>KEEP_1</b></div>")
        self.remote(duplicate)
        self.remote(rich)
        result = self.workspace.import_all(enable=True)
        self.assertEqual((result["found"], result["registered"], result["added"]), (3, 3, 2))
        self.assertEqual((result["bidirectional"], result["pull_only"]), (2, 1))
        self.assertEqual(result["errors"], {})
        state = self.workspace.state()
        self.assertTrue(state["discover"])
        self.assertNotEqual(state["notes"][duplicate.id]["file"], self.path.name)
        record = state["notes"][rich.id]
        path = self.root / record["file"]
        remote = replace(rich, text="Remote rich note\n", html="<div><b>Remote rich note</b></div>")
        self.remote(remote)
        self.workspace.inspect(sync=True)
        self.assertEqual(path.read_text(), remote.text)
        path.write_text("Unsynced local edits\n")
        self.workspace.inspect(sync=True)
        self.assertEqual(self.source.read(rich.id), remote)
        self.assertEqual(path.read_text(), "Unsynced local edits\n")

    def test_discovery_adds_new_notes_but_respects_disabled_existing_notes(self):
        self.assertEqual(self.workspace.import_all(), {})
        self.workspace.import_all(enable=True)
        self.workspace.enable(self.path.name, False)
        new = replace(self.note, id="new-note", title="New note")
        self.remote(new)
        result = self.workspace.import_all()
        self.assertEqual(result["added"], 1)
        self.assertFalse(self.workspace.state()["notes"][self.note.id]["sync_enabled"])
        self.assertTrue(self.workspace.state()["notes"][new.id]["sync_enabled"])
        self.assertEqual(self.workspace.import_all()["added"], 0)
        self.path.unlink()
        duplicate = replace(self.note, id="new-note-same-title")
        self.remote(duplicate)
        self.workspace.import_all()
        self.assertNotEqual(self.workspace.state()["notes"][duplicate.id]["file"], self.path.name)
        self.assertFalse(self.path.exists())

    def test_import_failure_does_not_prevent_other_notes_from_being_preserved(self):
        extra = replace(self.note, id="new-note", title="New note")
        self.remote(extra)
        original = self.source.read

        def unavailable(note_id=None):
            if note_id == self.note.id:
                raise RuntimeError("Locked")
            return original(note_id)

        self.source.read = unavailable
        result = self.workspace.import_all(enable=True)
        self.assertIn(self.note.id, result["errors"])
        self.assertEqual(result["added"], 1)
        self.assertEqual(self.root.joinpath("New note.md").read_text(), extra.text)
        self.assertEqual(json.loads((self.root / ".memo-sync/import-errors.json").read_text()),
                         result["errors"])
        self.root.joinpath("New note.md").write_text("Other notes still sync\n")
        results = self.workspace.inspect(sync=True)
        self.assertEqual(results[0]["status"], "unavailable")
        self.assertEqual(self.source.read(extra.id).text, "Other notes still sync\n")


if __name__ == "__main__":
    unittest.main()
