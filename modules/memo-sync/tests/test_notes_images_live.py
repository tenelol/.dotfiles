"""Explicit native regression for image paragraph reflow; uses only a disposable note."""
import argparse
import base64
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

FILES = Path(__file__).resolve().parents[1] / "files"
sys.path.insert(0, str(FILES))
import memo_sync as memo
from notes_text import NotesText


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--create", action="store_true", required=True)
    parser.parse_args()
    source = memo.Notes(FILES / "notes.js")
    with tempfile.TemporaryDirectory(prefix="memo-images-live-") as temporary:
        root = Path(temporary)
        image = root / "pixel.png"
        image.write_bytes(base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII="))
        title = "memo-sync image test " + uuid.uuid4().hex[:8]
        script = '''on run argv
tell application "Notes"
set n to make new note at default folder of default account with properties {body:"<div><h1>" & (item 1 of argv) & "</h1><h1>First</h1><h1>Second</h1></div>"}
make new attachment at n with data (POSIX file (item 2 of argv))
return id of n
end tell
end run'''
        note_id = subprocess.check_output(["/usr/bin/osascript", "-e", script, title, str(image)], text=True).strip()
        destination = None
        try:
            editor = NotesText()
            try:
                editor.select(title, lambda: source.request({"operation": "ui_state", "id": note_id})["selected"] == note_id)
            finally:
                editor.close()
            before = source.request({"operation": "ui_state", "id": note_id})
            workspace = memo.Workspace(root / "memo", source)
            path = workspace.register(note_id, sync=True)
            for suffix in ("ダークパターン\n\nMVP\n\nExplanation 🌱\n", "追記\n\n最後\n"):
                target = memo.image_plain(path.read_text()).replace("First", "First changed") + suffix
                path.write_text(target)
                assert workspace.inspect(path.name, sync=True)[0]["status"] == "in_sync"
                assert workspace.inspect(path.name)[0]["status"] == "in_sync"
                assert path.read_text() == target
                after = source.request({"operation": "ui_state", "id": note_id})
                assert before["attachments"] == after["attachments"]
                assert before["foreground"] == after["foreground"]
            destination = source.ensure_folder([title + ' destination'])
            source.move(source.read(note_id), destination)
            home = source.ensure_folder([])
            source.move(source.read(note_id), home)
            after = source.request({"operation": "ui_state", "id": note_id})
            assert before["attachments"] == after["attachments"]
            assert before["foreground"] == after["foreground"]
            subprocess.run(["/usr/bin/osascript", "-e", '''on run argv
tell application "Notes" to delete every attachment of note id (item 1 of argv)
end run''', note_id], check=True, capture_output=True, text=True)
            assert source.read(note_id).attachments == 0
            assert workspace.inspect(path.name, sync=True)[0]["status"] == "in_sync"
            path.write_text(path.read_text() + "After removing image\n")
            result = workspace.inspect(path.name, sync=True)[0]
            deadline = time.monotonic() + 15
            while result["status"] == "waiting" and time.monotonic() < deadline:
                time.sleep(1)
                result = workspace.inspect(path.name, sync=True)[0]
            assert result["status"] == "in_sync", result
            workspace.markdown(True)
            record = workspace.state()["notes"][note_id]
            assert record["markdown"] and not record.get("image_text")
            print("PASS: native image edits/moves, stable attachments/foreground, editing after image removal")
        finally:
            note = source.read(note_id)
            if note and note.title == title:
                source.trash(note)
            if destination:
                source.delete_folder(destination)


if __name__ == "__main__":
    main()
