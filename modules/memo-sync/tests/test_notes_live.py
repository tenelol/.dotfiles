"""Explicit macOS integration check, using only a dedicated disposable note."""

import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid


SCRIPT = Path(__file__).resolve().parents[1] / "files/memo_sync.py"
spec = importlib.util.spec_from_file_location("memo_sync_live", SCRIPT)
memo = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = memo
spec.loader.exec_module(memo)


def wait_for(check):
    until = time.monotonic() + 20
    while time.monotonic() < until:
        if check():
            return
        time.sleep(1)
    raise AssertionError("Automatic sync timed out")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    targets = parser.add_mutually_exclusive_group(required=True)
    targets.add_argument("--create", action="store_true")
    targets.add_argument("--note-id")
    args = parser.parse_args()
    source = memo.Notes(SCRIPT.with_name("notes.js"))
    note_id = args.note_id
    if args.create:
        # The only creation path has a unique, recognisable disposable title.
        title = "memo-sync 動作確認 " + uuid.uuid4().hex[:12]
        program = """ObjC.import("Foundation");
var data = $.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile;
var title = JSON.parse(ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding)));
var app = Application("Notes");
var note = app.Note({body: "<div><h1>" + title + "</h1></div><div>KEEP_0</div>"});
app.defaultAccount().defaultFolder().notes.push(note);
note.id();"""
        result = subprocess.run(["/usr/bin/osascript", "-l", "JavaScript", "-e", program],
                                input=json.dumps(title), text=True, capture_output=True, check=True, timeout=45)
        note_id = result.stdout.strip()
    note = source.read(note_id)
    if not note or not note.title.startswith("memo-sync 動作確認 "):
        raise ValueError("A dedicated memo-sync test note is required")
    root = Path(tempfile.mkdtemp(prefix="memo-sync-bidirectional-live-"))
    workspace = memo.Workspace(root, source)
    path = workspace.register(note_id)
    path.write_text(memo.file_text(note.text))
    workspace.enable(path.name)
    text = note.title + "\n\n" + "".join(
        "KEEP_" + str(i) + " 日本語 🌱 <tag> &  \t\n" for i in range(7)) + "\n"
    path.write_text(text)
    assert workspace.inspect(sync=True)[0]["status"] == "in_sync"
    assert source.read(note_id).text == text
    remote_text = text + "標準メモ側からの変更\n"
    source.replace(source.read(note_id), remote_text)
    assert workspace.inspect(sync=True)[0]["status"] == "in_sync"
    assert path.read_text() == remote_text
    stale = source.read(note_id)
    source.replace(stale, remote_text + "標準メモ側の競合\n")
    try:
        source.replace(stale, remote_text + "STALE_WRITE\n")
    except RuntimeError:
        pass
    else:
        raise AssertionError("A stale write was accepted")
    path.write_text(remote_text + "ファイル側の競合\n")
    assert workspace.inspect(sync=True)[0]["status"] == "conflict"
    assert path.read_text().endswith("ファイル側の競合\n")
    assert source.read(note_id).text.endswith("標準メモ側の競合\n")
    path.write_text(memo.file_text(source.read(note_id).text))
    workspace.enable(path.name)
    with (root / "watch.log").open("w") as log:
        watcher = subprocess.Popen([sys.executable, str(SCRIPT), "--root", str(root),
                                    "watch", "--interval", "1"], stdout=log, stderr=log)
        try:
            text = path.read_text() + "AUTOMATIC_FILE_EDIT\n"
            path.write_text(text)
            wait_for(lambda: source.read(note_id).text == text)
            text += "AUTOMATIC_NOTES_EDIT\n"
            source.replace(source.read(note_id), text)
            wait_for(lambda: path.read_text() == text)
        finally:
            watcher.terminate()
            watcher.wait(timeout=10)
    assert workspace.inspect()[0]["status"] == "in_sync"
    print(json.dumps({"note_id": note_id, "workspace": str(root),
                      "checks": ["push", "pull", "text_fidelity", "stale_write_rejected",
                                 "conflict_preserved", "automatic_push", "automatic_pull"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
