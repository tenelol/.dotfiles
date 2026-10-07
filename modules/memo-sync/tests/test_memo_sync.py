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
import threading
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch


MODULE = Path(__file__).resolve().parents[1]
SCRIPT = MODULE / "files/memo_sync.py"
sys.path.insert(0, str(SCRIPT.parent))
spec = importlib.util.spec_from_file_location("memo_sync", SCRIPT)
memo = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = memo
spec.loader.exec_module(memo)


class MemoSyncTests(unittest.TestCase):
    def test_extensionless_note_fills_blank_title_and_keeps_body_through_rename(self):
        self.workspace.markdown(True);self.workspace.discover_local()
        folder=self.root/'book';folder.mkdir();path=folder/'本';path.write_text('\n誰のためのデザイン\n')
        (folder/'image.png').write_bytes(b'not a note');(folder/'.hidden').write_text('Hidden\n')
        self.assertIn('create:book/本',self.workspace.local_work()[0])
        self.assertEqual(self.workspace.discover_local(filenames={'book/本'}),{})
        self.assertEqual(path.read_text(),'本\n誰のためのデザイン\n')
        note_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']=='book/本')
        self.assertEqual(self.source.read(note_id).title,'本')
        target=folder/'読書';path.rename(target)
        self.assertEqual(self.workspace.local_work()[0].get('move:book/本'),'book/読書')
        self.workspace.move_local('book/本','book/読書')
        self.assertEqual(self.workspace.inspect('book/読書',sync=True)[0]['status'],'in_sync')
        self.assertEqual(target.read_text(),'読書\n誰のためのデザイン\n')
        self.assertEqual(self.source.read(note_id).title,'読書')
        raw=folder/'本 [raw]';raw.write_text('\n<div>KEEP</div>\n')
        self.workspace.discover_local(filenames={'book/本 [raw]'})
        raw_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']=='book/本 [raw]')
        self.assertEqual(self.source.read(raw_id).title,'本 [raw]')
        self.assertEqual(raw.read_text(),'本 [raw]\n<div>KEEP</div>\n')
        self.assertFalse(any(r['file'].endswith(('image.png','.hidden')) for r in self.workspace.state()['notes'].values()))

    def test_unresolved_write_cannot_be_followed_by_automatic_deletion(self):
        self.workspace.discover_local();self.workspace.deletions(True)
        path=self.root/'pending.md';path.write_text('Pending\nKEEP\n');self.workspace.discover_local()
        note_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']==path.name)
        original=self.source.read(note_id);path.write_text('Pending\nEDITED\n')
        with patch.object(self.source,'replace',side_effect=RuntimeError('Unknown write outcome')):
            self.assertEqual(self.workspace.inspect(path.name,sync=True)[0]['status'],'interrupted')
        path.unlink()
        self.assertNotIn('delete:pending.md',self.workspace.local_work()[0])
        self.workspace.delete_note('pending.md')
        self.assertEqual(self.source.read(note_id),original)

    def test_rename_does_not_bypass_empty_body_protection(self):
        self.workspace.discover_local()
        old=self.root/'old.md';old.write_text('Old\nKEEP BODY\n');self.workspace.discover_local()
        note_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']==old.name)
        before=self.source.read(note_id);old.write_text('');new=old.with_name('new.md');old.rename(new)
        with self.assertRaises(ValueError):self.workspace.move_local(old.name,new.name)
        self.assertEqual(self.source.read(note_id),before)
        self.assertEqual(new.read_text(),'')

    def test_hardlink_is_not_an_explicit_case_only_rename(self):
        self.workspace.discover_local()
        old=self.root/'original.md';old.write_text('Original\n');self.workspace.discover_local()
        target=self.root/'copy.md';os.link(old,target)
        with self.assertRaises(ValueError):self.workspace.move_local(old.name,target.name,identified=True)
        self.assertTrue(os.path.samefile(old,target))

    def test_rename_before_creation_does_not_leave_an_interrupted_create(self):
        self.workspace.discover_local()
        old=self.workspace.root/'fresh.md';old.write_text('Fresh\n')
        target=old.with_name('renamed.md');read=memo.read_text;calls=[0]
        before=set(self.source.list_ids())
        def rename_before_write(path):
            if path==old:
                calls[0]+=1
                if calls[0]==2:old.rename(target)
            return read(path)
        with patch.object(memo,'read_text',side_effect=rename_before_write):
            self.workspace.discover_local(filenames={old.name})
        self.assertNotIn(old.name,self.workspace.state().get('creates',{}))
        self.assertEqual(set(self.source.list_ids()),before)
        self.workspace.discover_local(filenames={target.name})
        self.assertEqual(len(set(self.source.list_ids())-before),1)

    def test_rename_during_scan_waits_for_a_consistent_inventory(self):
        self.workspace.discover_local();self.workspace.deletions(True)
        old=self.workspace.root/'before.md';old.write_text('Before\nBODY\n');self.workspace.discover_local()
        target=self.workspace.root/'after.md';original_read=memo.read_text;renamed=[False]
        def rename_while_reading(path):
            if path==old and not renamed[0]:
                renamed[0]=True;old.rename(target);target.write_text('Before\nEDITED\n')
            return original_read(path)
        with patch.object(memo,'read_text',side_effect=rename_while_reading):
            work,_=self.workspace.local_work()
        self.assertNotIn('delete:before.md',work)
        self.assertNotIn('create:after.md',work)
        self.assertEqual(self.workspace.local_work()[0].get('move:before.md'),'after.md')

    def test_case_only_rename_updates_title_line_and_preserves_remaining_body(self):
        self.workspace.discover_local()
        old=self.root/'alpha.md';old.write_text('Original heading\nBODY\n')
        self.workspace.discover_local()
        note_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']==old.name)
        before=self.source.read(note_id)
        target=old.with_name('Alpha.md');old.rename(target)
        work,_=self.workspace.local_work()
        self.assertEqual(work.get('move:alpha.md'),'Alpha.md')
        self.workspace.move_local('alpha.md','Alpha.md')
        self.assertEqual(self.workspace.inspect('Alpha.md',sync=True)[0]['status'],'in_sync')
        after=self.source.read(note_id)
        self.assertEqual(after.title,'Alpha')
        self.assertEqual(after.text,'Alpha\nBODY\n')
        self.assertEqual(target.read_text(),'Alpha\nBODY\n')
        target.write_text('Alpha\nEDITED\n')
        self.assertEqual(self.workspace.inspect('Alpha.md',sync=True)[0]['status'],'in_sync')
        self.assertEqual(self.source.read(note_id).title,'Alpha')

    def test_explicit_shared_move_retains_sharing_native_body_and_local_draft(self):
        self.workspace.discover_local()
        folder=self.source.ensure_folder(())
        note=replace(self.source.create(folder,'Shared note\nOriginal\n'),shared=True)
        self.remote(note);self.workspace.import_all(enable=True)
        old=self.root/'Shared note.md';target=self.root/'else'/'Shared note.md';target.parent.mkdir()
        target.write_text('Shared note\nLocal draft\n');old.unlink()
        with self.assertRaises(ValueError):self.workspace.move_local(old.name,'else/Shared note.md')
        self.workspace.move_local(old.name,'else/Shared note.md',identified=True)
        current=self.source.read(note.id)
        self.assertTrue(current.shared);self.assertEqual(current.html,note.html)
        self.assertEqual(current.folder,('else',))
        self.assertEqual(target.read_text(),'Shared note\nLocal draft\n')
        self.assertFalse(self.workspace.state()['notes'][note.id]['sync_enabled'])

    def test_existing_markdown_can_fall_back_without_losing_table_cells(self):
        self.workspace.markdown(True);self.workspace.discover_local()
        path=self.root/'table-mode.md';path.write_text('# Table\n\n| A | B |\n|---|---|\n|one|two|\n')
        self.workspace.discover_local()
        text=path.read_text()+'\n> quoted\n';path.write_text(text)
        result=self.workspace.inspect(path.name,sync=True)[0]
        self.assertEqual(result['status'],'in_sync',result.get('error'))
        self.assertEqual(self.source.read(result['note_id']).text,text)
        self.assertTrue(self.workspace.state()['notes'][result['note_id']]['literal'])
        self.assertEqual(self.workspace.inspect(path.name,sync=True)[0]['status'],'in_sync')

    def test_unsupported_markdown_keeps_literal_source_and_syncs_both_ways(self):
        self.workspace.markdown(True)
        self.workspace.discover_local()
        text='---\n### Heading\n\n> quote\n\n![image](missing.png)\n\n<a href="x">HTML</a>\n'
        path=self.root/'literal.md';path.write_text(text)
        self.assertEqual(self.workspace.discover_local(filenames={path.name}),{})
        note_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']==path.name)
        self.assertTrue(self.workspace.state()['notes'][note_id]['literal'])
        self.assertEqual(self.source.read(note_id).text,text)
        path.write_text(text+'LOCAL\n')
        self.assertEqual(self.workspace.inspect(path.name,sync=True)[0]['status'],'in_sync')
        remote=self.source.read(note_id)
        self.remote(replace(remote,text=remote.text+'REMOTE\n',html=remote.html+'<div>REMOTE</div>'))
        self.assertEqual(self.workspace.inspect(path.name,sync=True)[0]['status'],'in_sync')
        self.assertEqual(path.read_text(),text+'LOCAL\nREMOTE\n')
        self.workspace.markdown(True)
        self.assertEqual(path.read_text(),text+'LOCAL\nREMOTE\n')

    def test_folder_poll_keeps_an_unresolved_file_error_visible(self):
        self.workspace.markdown(True)
        self.workspace.discover_local()
        path=self.root/'unsupported.md';path.write_text('invalid\x00text\n')
        self.assertIn(path.name,self.workspace.discover_local(filenames={path.name}))
        self.assertIn(path.name,self.workspace.discover_local(filenames=set()))
        path.write_text('Supported text\n')
        self.assertNotIn(path.name,self.workspace.discover_local(filenames={path.name}))

    def test_move_immediately_after_receiving_an_update_keeps_the_same_note(self):
        self.workspace.discover_local()
        path=self.root/'instant.md';path.write_text('Instant\n')
        self.workspace.discover_local()
        note_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']==path.name)
        self.source.replace(self.source.read(note_id),'Instant\nRemote edit\n')
        self.assertEqual(self.workspace.inspect(path.name,sync=True)[0]['status'],'in_sync')
        target=self.root/'moved'/path.name;target.parent.mkdir();path.rename(target)
        self.assertEqual(self.workspace.local_work()[0].get('move:instant.md'),'moved/instant.md')
        self.workspace.move_local('instant.md','moved/instant.md')
        self.assertEqual(self.workspace.state()['notes'][note_id]['file'],'moved/instant.md')
        self.assertEqual(self.source.read(note_id).text,'Instant\nRemote edit\n')

    def test_recreated_filename_binds_to_new_note_after_deletion(self):
        self.workspace.markdown(True);self.workspace.discover_local();self.workspace.deletions(True)
        path=self.root/'reuse.md';path.write_text('# Old\n')
        self.workspace.discover_local();self.workspace.local_work()
        old_id=next(iter(self.workspace.state()['notes']))
        path.unlink();self.workspace.delete_note('reuse.md')
        text='# New\n\n| A | B |\n|---|---|\n|one|two|\n'
        path.write_text(text);self.workspace.discover_local()
        active=[k for k,r in self.workspace.state()['notes'].items() if not r.get('deleted')]
        self.assertEqual(len(active),1);self.assertNotEqual(active[0],old_id)
        self.assertEqual(len(self.workspace.inspect('reuse.md')),1)
        self.assertEqual(len(self.workspace.inspect()),1)
        self.workspace.enable('reuse.md')
        self.assertTrue(memo.markdown_matches(self.source.read(active[0]),text))
        path.unlink();self.workspace.delete_note('reuse.md')
        self.assertIsNone(self.source.read(active[0]))

    def test_table_cells_and_note_identity_survive_moves_in_both_directions(self):
        self.workspace.markdown(True)
        self.workspace.discover_local()
        path = self.root / "table.md"
        text = "# Table\n\n| A | B |\n|---|---|\n|one|日本語|\n|three|four|\n"
        path.write_text(text)
        self.workspace.discover_local()
        state = self.workspace.state()
        note_id = next(key for key, r in state['notes'].items() if r['file'] == path.name)
        note = self.source.read(note_id)
        self.assertTrue(memo.markdown_matches(note, text))
        bad = replace(note, html=note.html.replace('>one</td>', '>on</td>').replace('>日本語</td>', '>e日本語</td>'))
        self.assertFalse(memo.markdown_matches(bad, text))
        self.workspace.local_work()
        target = self.root / "b" / path.name
        target.parent.mkdir();path.rename(target)
        self.assertEqual(self.workspace.local_work()[0]["move:table.md"], "b/table.md")
        self.workspace.move_local("table.md", "b/table.md")
        moved = self.source.read(note_id)
        self.assertEqual(moved.fingerprint, note.fingerprint)
        destination = self.source.ensure_folder(("c",))
        self.source.move(moved, destination)
        self.workspace.discover_local()
        self.assertFalse(target.exists())
        self.assertEqual((self.root/'c/table.md').read_text(), text)
        self.assertEqual(self.workspace.state()['notes'][note_id]['file'], 'c/table.md')
        self.assertEqual(self.workspace.inspect('c/table.md')[0]['status'], 'in_sync')

    def test_remote_move_does_not_overwrite_a_local_file(self):
        self.workspace.discover_local()
        path = self.root / 'source.md';path.write_text('Source\n')
        self.workspace.discover_local()
        note_id = next(key for key, r in self.workspace.state()['notes'].items() if r['file']=='source.md')
        folder = self.source.ensure_folder(('destination',))
        target = self.root/'destination/source.md';target.parent.mkdir();target.write_text('Keep this file\n')
        self.source.move(self.source.read(note_id), folder)
        result=self.workspace.inspect('source.md',sync=True)[0]
        self.assertEqual(result['status'],'folder_changed')
        self.assertEqual(target.read_text(),'Keep this file\n')
        self.assertEqual(path.read_text(),'Source\n')

    def test_interrupted_move_reserves_destination_and_blocks_deletion(self):
        self.workspace.discover_local()
        path=self.root/'old.md';path.write_text('Original\n')
        self.workspace.discover_local();self.workspace.deletions(True);self.workspace.local_work()
        target=self.root/'destination/new.md';target.parent.mkdir();path.rename(target)
        ids=self.source.list_ids();move=self.source.move
        def interrupted(expected, destination):
            move(expected, destination)
            raise RuntimeError('response lost after move')
        self.source.move=interrupted
        with self.assertRaises(RuntimeError):self.workspace.move_local('old.md','destination/new.md')
        self.workspace.discover_local()
        self.assertEqual(self.source.list_ids(),ids)
        self.assertNotIn('create:destination/new.md',self.workspace.local_work()[0])
        self.workspace.delete_note('old.md')
        self.assertEqual(self.source.list_ids(),ids)
        self.assertEqual(self.workspace.inspect('old.md')[0]['status'],'move_interrupted')

    def test_new_folder_and_file_are_armed_at_publication(self):
        self.workspace.deletions(True)
        self.source.ensure_folder(("remote",))
        self.workspace.discover_local()
        (self.root / "remote").rmdir()
        self.assertIn("delete-folder:remote", self.workspace.local_work()[0])
        self.workspace.delete_folder("remote")
        path = self.root / "quick.md"
        path.write_text("Quick\n")
        create = self.source.create
        def remove_during_create(folder, text):
            note = create(folder, text)
            path.unlink()
            return note
        self.source.create = remove_during_create
        self.workspace.discover_local()
        self.assertIn("delete:quick.md", self.workspace.local_work()[0])

    def test_cached_baseline_rechecks_changed_history(self):
        self.workspace.register()
        record = self.workspace.state()["notes"][self.note.id]
        self.assertEqual(self.workspace.base(record), self.note)
        self.assertEqual(self.workspace.base(record), self.note)
        path = self.workspace.meta / record["base"]
        value = json.loads(path.read_text())
        value["text"] += "tampered"
        path.write_text(json.dumps(value))
        with self.assertRaises(ValueError):
            self.workspace.base(record)

    def test_image_text_sync_uses_partial_editor_and_retries_only_before_writing(self):
        note = replace(self.note, title="Image note", text="Image note\nBEFORE\n\ufffc\n",
                       html='<div>Image note</div><div>BEFORE</div><div><img src="data:image/png;base64,AA=="></div>',
                       attachments=1)
        self.remote(note)
        path = self.workspace.register(note.id, sync=True)
        self.assertTrue(self.workspace.state()["notes"][note.id]["image_text"])
        path.write_text("Image note\nAFTER\n\n")
        self.source.replace_images = lambda *args: (_ for _ in ()).throw(memo.DeferredSync("busy"))
        result = self.workspace.inspect(path.name, sync=True)[0]
        self.assertEqual(result["status"], "waiting")
        self.assertEqual(result["error"], "busy")
        self.assertNotIn("pending", self.workspace.state()["notes"][note.id])
        self.assertEqual(self.source.read(note.id), note)
        def partial(expected, text):
            updated = replace(expected, text="Image note\nAFTER\n\n\ufffc\n",
                              html=expected.html.replace("BEFORE", "AFTER"), modified="later")
            self.remote(updated)
            return updated
        self.source.replace_images = partial
        self.assertEqual(self.workspace.inspect(path.name, sync=True)[0]["status"], "in_sync")
        self.assertEqual(self.workspace.inspect(path.name)[0]["status"], "in_sync")
        self.assertEqual(self.source.read(note.id).attachments, 1)
        self.assertNotIn(path.name, self.workspace.local_work()[0])

    def test_removed_folder_trashes_notes_before_deleting_empty_folder(self):
        self.workspace.discover_local()
        (self.root / "parent" / "child").mkdir(parents=True)
        path = self.root / "parent" / "child" / "test.md"
        path.write_text("Test\nBody\n")
        self.workspace.discover_local()
        self.workspace.deletions(True)
        self.workspace.local_work()
        path.unlink()
        path.parent.rmdir()
        path.parent.parent.rmdir()
        work, state = self.workspace.local_work()
        self.assertIn("delete:parent/child/test.md", work)
        self.assertIn("delete-folder:parent/child", work)
        self.assertFalse(memo.folder_ready(state, "parent/child"))
        self.workspace.delete_note("parent/child/test.md")
        self.assertIn("delete-folder:parent/child", self.workspace.local_work()[0])
        self.workspace.delete_folder("parent/child")
        self.assertIn("delete-folder:parent", self.workspace.local_work()[0])
        self.workspace.delete_folder("parent")
        self.assertEqual([f["path"] for f in self.source.folders()], [[]])

    def test_moved_folder_is_not_a_deletion_and_unknown_remote_content_is_preserved(self):
        self.workspace.discover_local()
        (self.root / "old").mkdir()
        self.workspace.discover_local()
        self.workspace.deletions(True)
        self.workspace.local_work()
        (self.root / "old").rename(self.root / "new")
        self.assertNotIn("delete-folder:old", self.workspace.local_work()[0])
        self.workspace.delete_folder("old")
        self.assertTrue(any(f["path"] == ["old"] for f in self.source.folders()))
        (self.root / "new").rename(self.root / "old")
        folder = next(f for f in self.source.folders() if f["path"] == ["old"])
        self.source.create(folder, "Unknown remote note\n")
        (self.root / "old").rmdir()
        with self.assertRaises(RuntimeError):
            self.workspace.delete_folder("old")
        self.assertIn(folder, self.source.folders())

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
    def test_consecutive_saves_follow_the_verified_write_without_losing_the_newer_file(self):
        first, latest = 'First save\n', 'Latest save\n'
        self.path.write_text(first)
        original = self.source.replace
        def save_again_during_write(expected, text):
            updated = original(expected, text)
            self.path.write_text(latest)
            return updated
        self.source.replace = save_again_during_write
        self.assertEqual(self.workspace.inspect(sync=True)[0]['status'], 'push_pending')
        self.assertEqual(self.path.read_text(), latest)
        self.assertEqual(self.source.read(self.note.id).text, first)
        self.assertNotIn('pending', self.workspace.state()['notes'][self.note.id])
        self.source.replace = original
        self.assertEqual(self.workspace.inspect(sync=True)[0]['status'], 'in_sync')
        self.assertEqual(self.source.read(self.note.id).text, latest)

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


class FolderSyncTests(unittest.TestCase):
    remote = MemoSyncTests.remote
    cli = MemoSyncTests.cli

    def setUp(self):
        MemoSyncTests.setUp(self)
        self.note = replace(self.note, html="<div>Title</div><div>KEEP_1</div>", text="Title\nKEEP_1\n")
        self.remote(self.note)
        self.path = self.workspace.register()

    def test_mkdir_and_file_save_create_nested_notes_and_then_sync(self):
        directory = self.root / "a/日本語"
        directory.mkdir(parents=True)
        path = directory / "名前.md"
        path.write_text("名前\n  <tag> & 日本語 🌱\t\n\nKEEP_7\n")
        self.assertEqual(self.workspace.discover_local(stable=True), {})
        self.assertEqual(len(self.source.list_ids()), 1)
        self.assertEqual(self.workspace.discover_local(stable=True), {})
        state = self.workspace.state()
        created_id = next(key for key in state["notes"] if key != self.note.id)
        self.assertEqual(state["notes"][created_id]["file"], "a/日本語/名前.md")
        created = self.source.read(created_id)
        self.assertEqual(created.folder, ("a", "日本語"))
        self.assertEqual(created.text, path.read_text())
        self.assertEqual(self.workspace.discover_local(), {})
        self.assertEqual(len(self.source.list_ids()), 2)
        path.write_text(path.read_text() + "LOCAL_EDIT\n")
        self.cli("sync", "a/日本語/名前.md")
        self.assertEqual(self.source.read(created_id).text, path.read_text())
        self.remote(replace(self.source.read(created_id), text=path.read_text() + "REMOTE_EDIT\n"))
        self.workspace.inspect("a/日本語/名前.md", sync=True)
        self.assertTrue(path.read_text().endswith("REMOTE_EDIT\n"))
        self.cli("disable", "a/日本語/名前.md")

    def test_remote_empty_folders_and_notes_are_imported_at_the_right_path(self):
        folder = self.source.ensure_folder(("remote", "child"))
        self.workspace.discover_local()
        self.assertTrue((self.root / "remote/child").is_dir())
        remote = replace(self.note, id="remote-child", title="Remote",
                         folder_id=folder["id"], folder=tuple(folder["path"]),
                         account=folder["account"])
        self.remote(remote)
        path = self.workspace.register(remote.id, sync=True)
        self.assertEqual(path.relative_to(self.workspace.root).as_posix(), "remote/child/Remote.md")
        self.assertEqual(path.read_text(), remote.text)

    def test_failed_creation_keeps_local_backup_and_never_retries(self):
        path = self.root / "new.md"
        path.write_text("New note\nOriginal local text\n")
        with patch.object(self.source, "create", side_effect=RuntimeError("Timeout")) as create:
            self.assertIn("new.md", self.workspace.discover_local())
            self.workspace.discover_local()
            self.assertEqual(create.call_count, 1)
        self.assertEqual(path.read_text(), "New note\nOriginal local text\n")
        self.assertEqual((self.workspace.meta / "local-history" /
                          (memo.digest(path.read_text()) + ".txt")).read_text(), path.read_text())
        self.assertEqual(self.workspace.inspect()[-1]["status"], "create_interrupted")

    def test_moves_are_not_duplicated_or_recreated(self):
        moved = self.root / "a" / self.path.name
        moved.parent.mkdir()
        self.path.rename(moved)
        self.assertIn(moved.relative_to(self.root).as_posix(), self.workspace.discover_local())
        self.assertEqual(len(self.source.list_ids()), 1)
        self.assertFalse(self.path.exists())
        # Renaming/deleting a known Notes folder must not recreate its old name.
        folder = self.source.ensure_folder(("old",))
        self.workspace.discover_local()
        catalog = self.source.folders()
        next(f for f in catalog if f["id"] == folder["id"])["path"] = ["renamed"]
        memo.atomic_json(self.fixtures / "folders.json", catalog)
        self.assertIn("renamed", self.workspace.discover_local())
        self.assertFalse((self.root / "renamed").exists())

    def test_metadata_keeps_existing_snapshot_hashes_and_blocks_path_escape(self):
        old = asdict(self.note)
        for key in ("folder", "folder_id", "account", "default_account"):
            old.pop(key)
        old.pop("modified")
        expected = memo.digest(json.dumps(old, ensure_ascii=False, sort_keys=True))
        self.assertEqual(self.note.fingerprint, expected)
        moved = replace(self.note, folder=("a",), folder_id="new-folder", account="account")
        self.assertEqual(moved.fingerprint, expected)
        for name in ("../outside.md", ".memo-sync/private.md", "a/../outside.md", "."):
            with self.assertRaises(ValueError):
                self.workspace.note_path(name)
        outside = self.directory / "outside"
        outside.mkdir()
        (self.root / "linked").symlink_to(outside)
        with self.assertRaises(OSError):
            self.workspace.note_path("linked/private.md")
        self.workspace.discover_local()
        self.assertEqual(list(outside.iterdir()), [])


class WatchLatencyTests(unittest.TestCase):
    def test_editing_a_blocked_rename_retries_with_the_resolved_body(self):
        MemoSyncTests.setUp(self)
        self.workspace.discover_local()
        old=self.root/'old.md';old.write_text('Original\nBODY\n');self.workspace.discover_local()
        note_id=next(k for k,r in self.workspace.state()['notes'].items() if r['file']==old.name)
        remote=self.source.replace(self.source.read(note_id),'Original\nREMOTE BODY\n')
        target=self.root/'renamed.md';old.rename(target);clock=[0.0];resolved=[False]
        class Done(Exception):pass
        def tick(seconds):
            clock[0]+=seconds
            if clock[0]>=2 and not resolved[0]:target.write_text(remote.text);resolved[0]=True
            if self.source.read(note_id).title=='renamed' or clock[0]>7:raise Done
        with patch.object(memo.time,'monotonic',side_effect=lambda:clock[0]), \
             patch.object(memo.time,'sleep',side_effect=tick),self.assertRaises(Done):
            memo.watch_workspace(self.workspace,1)
        self.assertEqual(self.source.read(note_id).text,'renamed\nREMOTE BODY\n')
        self.assertEqual(target.read_text(),'renamed\nREMOTE BODY\n')

    def test_move_retries_a_transient_failure_before_any_native_mutation(self):
        MemoSyncTests.setUp(self)
        self.workspace.discover_local()
        path=self.root/'retry-move.md';path.write_text('Move\n')
        self.workspace.discover_local()
        target=self.root/'destination'/path.name;target.parent.mkdir();path.rename(target)
        ensure=self.source.ensure_folder;failed=[False];clock=[0.0]
        def flaky(parts):
            if not failed[0]:failed[0]=True;raise RuntimeError('Temporary destination lookup failure')
            return ensure(parts)
        class Done(Exception):pass
        def tick(seconds):
            clock[0]+=seconds
            if any(r['file']=='destination/retry-move.md' for r in self.workspace.state()['notes'].values()) or clock[0]>8:raise Done
        with patch.object(self.source,'ensure_folder',side_effect=flaky), \
             patch.object(self.workspace,'discover_local',return_value={}), \
             patch.object(memo.time,'monotonic',side_effect=lambda:clock[0]), \
             patch.object(memo.time,'sleep',side_effect=tick),self.assertRaises(Done):
            memo.watch_workspace(self.workspace,1)
        self.assertTrue(any(r['file']=='destination/retry-move.md' for r in self.workspace.state()['notes'].values()))

    def test_transient_read_failure_retries_the_same_saved_content(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = memo.FixtureNotes(Path(temporary)/"fixtures")
            source.directory.mkdir()
            note = memo.Note("retry", "Retry", "<div>Retry</div>", "Retry\n", "old")
            (source.directory / (memo.digest(note.id)+".json")).write_text(json.dumps(asdict(note)))
            workspace = memo.Workspace(Path(temporary)/"memo", source)
            path = workspace.register(note.id, sync=True)
            path.write_text("Retry\nSaved once\n")
            read = source.read
            failures = [1]
            def flaky(note_id=None):
                if failures[0]:
                    failures[0] -= 1
                    raise RuntimeError("Temporary Notes read failure")
                return read(note_id)
            clock = [0.0]
            class Done(Exception): pass
            def tick(seconds):
                clock[0] += seconds
                if read(note.id).text == "Retry\nSaved once\n" or clock[0] > 6: raise Done
            with patch.object(source,"read",side_effect=flaky), \
                 patch.object(memo.time,"monotonic",side_effect=lambda: clock[0]), \
                 patch.object(memo.time,"sleep",side_effect=tick), self.assertRaises(Done):
                memo.watch_workspace(workspace,1)
            self.assertEqual(read(note.id).text,"Retry\nSaved once\n")

    remote = MemoSyncTests.remote

    def test_missing_state_never_recreates_existing_notes(self):
        MemoSyncTests.setUp(self)
        self.root.mkdir()
        path=self.root/'orphan.md';path.write_text('Existing mirror\n')
        before=self.source.list_ids()
        try:
            result=subprocess.run([sys.executable,str(SCRIPT),'--root',str(self.root),
                                   '--fixture-dir',str(self.fixtures),'watch'],capture_output=True,text=True,timeout=1)
        except subprocess.TimeoutExpired:
            self.fail('Watcher did not stop when existing files had no mapping state')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('state.json',result.stderr)
        self.assertEqual(self.source.list_ids(),before)
        self.assertEqual(path.read_text(),'Existing mirror\n')

    def test_invalid_file_does_not_stop_other_notes(self):
        MemoSyncTests.setUp(self)
        self.workspace.discover_local()
        (self.root/'broken.md').write_bytes(b'\xff\xfe')
        os.mkfifo(self.root/'pipe.md')
        (self.root/'good.md').write_text('Good note\n')
        worker=subprocess.Popen([sys.executable,str(SCRIPT),'--root',str(self.root),
                                 '--fixture-dir',str(self.fixtures),'watch'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        try:
            until=time.monotonic()+3
            while time.monotonic()<until:
                if any(self.source.read(k).title=='Good note' for k in self.source.list_ids()):break
                time.sleep(.05)
            self.assertTrue(any(self.source.read(k).title=='Good note' for k in self.source.list_ids()))
            self.assertIn('broken.md',json.loads((self.workspace.meta/'local-errors.json').read_text()))
            self.assertIn('pipe.md',json.loads((self.workspace.meta/'local-errors.json').read_text()))
        finally:
            worker.terminate();worker.wait(timeout=3)

    def test_remote_changes_are_not_starved_by_index_polling_or_audits(self):
        class Done(Exception):
            pass
        for slow_index in (True, False):
            with self.subTest(slow_index=slow_index):
                clock = [0.0]
                handled = []
                calls = [0]
                notes = {} if slow_index else {str(i): {"file": f"{i}.md"} for i in range(30)}
                state = {"notes": notes, "discover": True}
                def local_work():
                    clock[0] += .1 if slow_index else 0
                    return {}, state
                def index():
                    clock[0] += .8 if slow_index else .01
                    calls[0] += 1
                    return {"new": "updated"} if slow_index else {
                        key: "updated" if key == "29" and calls[0] > 1 else "old" for key in notes}
                def inspect(filename, **kwargs):
                    if filename == "29.md":
                        handled.append(clock[0]);raise Done
                    return []
                def imported(**kwargs):
                    handled.append(clock[0]);raise Done
                def tick(seconds):
                    clock[0] += seconds
                    if clock[0] > 5:raise Done
                workspace = SimpleNamespace(local_work=local_work, source=SimpleNamespace(index=index),
                    discover_local=lambda **kwargs: None, import_all=imported, inspect=inspect,
                    base=lambda record: SimpleNamespace(modified="old"))
                with patch.object(memo.time, "monotonic", side_effect=lambda: clock[0]), \
                     patch.object(memo.time, "sleep", side_effect=tick), self.assertRaises(Done):
                    memo.watch_workspace(workspace, 1)
                self.assertTrue(handled, "A real remote change waited behind polling or unchanged audit entries")
                self.assertLess(handled[0], 3)

    def test_nested_folder_deletion_shares_one_absence_grace_period(self):
        MemoSyncTests.setUp(self)
        self.workspace.discover_local()
        path = self.root / "parent" / "child" / "test.md"
        path.parent.mkdir(parents=True)
        path.write_text("Test\nBody\n")
        self.workspace.discover_local();self.workspace.deletions(True);self.workspace.local_work()
        path.unlink();path.parent.rmdir();path.parent.parent.rmdir()
        clock, removed = [0.0], []
        trash, delete_folder = self.source.trash, self.source.delete_folder
        def note_removed(note):
            result=trash(note);removed.append(clock[0]);return result
        def folder_removed(folder):
            result=delete_folder(folder);removed.append(clock[0]);return result
        def tick(seconds):
            clock[0] += seconds
            if len(removed)==3 or clock[0]>20:raise KeyboardInterrupt
        self.source.trash=note_removed;self.source.delete_folder=folder_removed
        with patch.object(memo.time,"monotonic",side_effect=lambda:clock[0]), \
             patch.object(memo.time,"sleep",side_effect=tick), self.assertRaises(KeyboardInterrupt):
            memo.watch_workspace(self.workspace, 2)
        self.assertEqual(len(removed),3)
        self.assertLess(removed[-1]-removed[0],1,"The parent waited a new grace period at every directory level")

    def test_a_save_does_not_wait_for_a_slow_whole_notebook_scan(self):
        MemoSyncTests.setUp(self)
        self.note = replace(self.note, html="<div>Title</div><div>KEEP_1</div>", text="Title\nKEEP_1\n")
        self.remote(self.note)
        path = self.workspace.register(sync=True)
        for index in range(11):
            note = replace(self.note, id=f"other-{index}", title=f"Other {index}")
            self.remote(note)
            self.workspace.register(note.id, sync=True)
        original = self.source.read
        started, stop = threading.Event(), threading.Event()

        def slow_read(note_id=None):
            started.set()
            if stop.wait(0.2):
                raise KeyboardInterrupt
            return original(note_id)

        self.source.read = slow_read
        result = []
        with patch.object(memo, "FixtureNotes", return_value=self.source), \
             patch.object(memo, "print_result"), \
             patch.object(memo.time, "sleep", side_effect=lambda seconds: stop.wait(seconds)):
            worker = threading.Thread(target=lambda: result.append(memo.main([
                "--root", str(self.root), "--fixture-dir", str(self.fixtures),
                "watch", "--interval", "1"])), daemon=True)
            worker.start()
            try:
                self.assertTrue(started.wait(2), "Watcher did not start reading")
                text = "Title\nSAVED_WHILE_READING_OTHER_NOTES\n"
                start = time.monotonic()
                path.write_text(text)
                until = start + 2.5
                while time.monotonic() < until:
                    if original(self.note.id).text == text:
                        break
                    stop.wait(0.02)
                self.assertEqual(original(self.note.id).text, text,
                                 "Saving one file waited for the full notebook scan")
            finally:
                stop.set()
                worker.join(3)
        self.assertFalse(worker.is_alive())
        self.assertEqual(result, [0])


class DeletionAndMarkdownTests(unittest.TestCase):
    def test_native_inline_code_and_code_block_keep_their_whitespace(self):
        note = memo.Note("code", "inline", '<div><font face="Courier"><tt>inline</tt></font>'
                         '<span style="font-size: 13px"><tt><br></tt></span></div>'
                         '<div><font face="Courier"><tt>  indented\tcode</tt></font></div>',
                         "inline\n  indented\tcode\n", "now")
        memo.verify_markdown(note, "`inline`\n\n```\n  indented\tcode\n```\n")
        with self.assertRaises(ValueError):
            memo.verify_markdown(note, "`inline`\n\n```\nindented code\n```\n")

    remote = MemoSyncTests.remote

    def setUp(self):
        MemoSyncTests.setUp(self)
        self.note = replace(self.note, html="<div>Title</div><div>KEEP_1</div>", text="Title\nKEEP_1\n")
        self.remote(self.note)
        self.path = self.workspace.register(sync=True)

    def test_file_deletion_preserves_versions_and_tombstone_prevents_reimport(self):
        self.workspace.deletions(True)
        self.workspace.local_work()
        original = self.path.read_text()
        self.path.unlink()
        self.assertIn("delete:" + self.path.name, self.workspace.local_work()[0])
        self.workspace.delete_note(self.path.name)
        self.assertIsNone(self.source.read(self.note.id))
        self.assertEqual(self.workspace.inspect()[0]["status"], "deleted")
        self.assertEqual((self.workspace.meta/"local-history"/(memo.digest(original)+".txt")).read_text(), original)
        self.remote(self.note)
        self.workspace.import_all(enable=True)
        self.assertFalse(self.path.exists())

    def test_missing_before_enable_moves_and_editor_replacement_are_not_deletes(self):
        self.path.unlink()
        self.workspace.deletions(True)
        self.assertNotIn("delete:" + self.path.name, self.workspace.local_work()[0])
        self.path.write_text(self.note.text)
        self.workspace.local_work()
        renamed = self.root / "renamed.md"
        self.path.rename(renamed)
        self.assertNotIn("delete:" + self.path.name, self.workspace.local_work()[0])
        renamed.rename(self.path)
        self.workspace.local_work()
        self.path.unlink()
        self.path.write_text(self.note.text)
        self.workspace.delete_note(self.path.name)
        self.assertIsNotNone(self.source.read(self.note.id))

    def test_remote_change_and_ambiguous_failure_stop_deletion(self):
        self.workspace.deletions(True)
        self.workspace.local_work()
        self.path.unlink()
        self.remote(replace(self.note, text="New remote content\n", html="<div>New remote content</div>"))
        with self.assertRaises(RuntimeError):
            self.workspace.delete_note(self.path.name)
        self.remote(self.note)
        with patch.object(self.source, "trash", side_effect=RuntimeError("Timeout")) as trash:
            with self.assertRaises(RuntimeError):
                self.workspace.delete_note(self.path.name)
            self.workspace.delete_note(self.path.name)
            self.assertEqual(trash.call_count, 1)
        self.assertEqual(self.workspace.inspect()[0]["status"], "delete_interrupted")

    def test_deletion_immediately_after_a_verified_push_can_complete(self):
        self.workspace.deletions(True)
        self.workspace.local_work()
        self.path.write_text("Title\nSaved then deleted\n")
        self.workspace.local_work()
        original = self.source.replace

        def delete_after_write(expected, text):
            updated = original(expected, text)
            self.path.unlink()
            return updated

        self.source.replace = delete_after_write
        self.workspace.inspect(sync=True)
        record = self.workspace.state()["notes"][self.note.id]
        self.assertNotIn("pending", record)
        self.assertEqual(self.workspace.base(record).text, "Title\nSaved then deleted\n")
        self.workspace.delete_note(self.path.name)
        self.assertIsNone(self.source.read(self.note.id))

    def test_markdown_roundtrip_preserves_content_and_original_file_syntax(self):
        self.workspace.markdown(True)
        fence = chr(96) * 3
        text = "# Title\n\n## Heading\n\n**bold** and *italic*\n\n- KEEP_1\n- KEEP_2\n\n" + fence + "\n  code\tKEEP\n" + fence + "\n"
        self.path.write_text(text)
        result = self.workspace.inspect(sync=True)[0]
        self.assertEqual(result["status"], "in_sync", result.get("error"))
        remote = self.source.read(self.note.id)
        self.assertIn("<h1", remote.html)
        self.assertIn("<strong>", remote.html)
        self.assertIn("<ul>", remote.html)
        self.assertEqual(self.path.read_text(), text)
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.remote(replace(remote, html=remote.html.replace("KEEP_2", "REMOTE_2"),
                            text=remote.text.replace("KEEP_2", "REMOTE_2")))
        self.assertEqual(self.workspace.inspect(sync=True)[0]["status"], "in_sync")
        self.assertIn("REMOTE_2", memo.markdown_html(self.path.read_text())[1])
        for body in ("1. ordered\n", "[link](https://example.com)\n", "![image](x.png)\n",
                     "- [ ] task\n", "~~struck~~\n", "<div>raw HTML</div>\n", "### Third\n",
                     "> quoted\n", "---\n", ""):
            with self.assertRaises(ValueError):
                memo.markdown_html(body)
        for tag in ("p", "div"):
            note = replace(self.note, html="".join(f"<{tag}>KEEP_{i}</{tag}>" for i in range(7)),
                           text="".join(f"KEEP_{i}\n" for i in range(7)))
            converted = memo.markdown_text(note)
            for i in range(7):
                self.assertIn(f"KEEP_{i}", memo.markdown_html(converted)[1])


if __name__ == "__main__":
    unittest.main()
