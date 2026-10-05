"""Explicit native regression for image paragraph reflow; uses only a disposable note."""
import argparse
import base64
from pathlib import Path
import subprocess
import sys
import tempfile
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
            print("PASS: native multiline image edits, stable local baseline, attachments, and foreground")
        finally:
            note = source.read(note_id)
            if note and note.title == title:
                source.trash(note)


if __name__ == "__main__":
    main()
