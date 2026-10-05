#!/usr/bin/env python3
"""Register Notes as files and inspect both directions without overwriting either side."""

import argparse
from contextlib import contextmanager
from dataclasses import asdict, dataclass
import difflib
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time
import uuid


MAX_BYTES = 16 * 1024 * 1024


def digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def file_text(value):
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    return value if not value or value.endswith("\n") else value + "\n"


@dataclass(frozen=True)
class Note:
    id: str
    title: str
    html: str
    text: str
    modified: str
    attachments: int = 0
    shared: bool = False

    @classmethod
    def parse(cls, value):
        if not isinstance(value, dict):
            raise ValueError("メモのスナップショットが不正です。")
        try:
            note = cls(**value)
        except TypeError as error:
            raise ValueError("メモのスナップショットが不正です。") from error
        if not all(isinstance(getattr(note, key), str) for key in
                   ("id", "title", "html", "text", "modified")) or not note.id:
            raise ValueError("メモのスナップショットが不正です。")
        if type(note.attachments) is not int or note.attachments < 0 or type(note.shared) is not bool:
            raise ValueError("メモの属性が不正です。")
        if len(json.dumps(value, ensure_ascii=False).encode()) > MAX_BYTES:
            raise ValueError("メモが初期版の容量上限を超えています。")
        return note

    @property
    def fingerprint(self):
        content = asdict(self)
        content.pop("modified")  # Timestamp-only housekeeping is not a content edit.
        return digest(json.dumps(content, ensure_ascii=False, sort_keys=True))


class Notes:
    def __init__(self, bridge):
        self.bridge = bridge

    def read(self, note_id=None):
        if sys.platform != "darwin":
            raise RuntimeError("標準メモへの接続はmacOSでのみ利用できます。")
        request = {"operation": "read", "id": note_id} if note_id else {"operation": "selected"}
        result = subprocess.run(
            ["/usr/bin/osascript", "-l", "JavaScript", str(self.bridge)],
            input=json.dumps(request), text=True, encoding="utf-8",
            capture_output=True, timeout=45,
        )
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or "標準メモから読み取れませんでした。")
        if len(result.stdout.encode()) > MAX_BYTES:
            raise ValueError("メモが初期版の容量上限を超えています。")
        value = json.loads(result.stdout)
        if not isinstance(value, dict) or ("note" not in value and "error" not in value):
            raise ValueError("標準メモからの応答形式が不正です。")
        if value.get("error"):
            raise RuntimeError(value["error"])
        note = Note.parse(value["note"]) if value.get("note") is not None else None
        if note_id and note and note.id != note_id:
            raise ValueError("登録したメモIDと読取結果が一致しません。")
        return note


class FixtureNotes:
    """Local snapshots for offline demonstrations; never connects to Notes."""

    def __init__(self, directory):
        self.directory = Path(directory)

    def read(self, note_id=None):
        name = digest(note_id) + ".json" if note_id else "selected.json"
        path = self.directory / name
        if not path.exists():
            return None
        note = Note.parse(json.loads(read_text(path)))
        if note_id and note.id != note_id:
            raise ValueError("fixtureのメモIDが一致しません。")
        return note


def read_text(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "r", encoding="utf-8") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_BYTES:
            raise ValueError("通常のテキストファイルではないか、容量上限を超えています。")
        return stream.read()


def write_new(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as stream:
        stream.write(text)
        stream.flush()
        os.fsync(stream.fileno())


def atomic_json(path, value):
    temporary = path.with_name("." + path.name + "." + uuid.uuid4().hex)
    write_new(temporary, json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    try:
        if path.is_symlink():
            raise ValueError("管理ファイルへのシンボリックリンクは使用できません。")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def classify(base, local, remote):
    if remote is None:
        return "remote_missing"
    if remote.id != base.id:
        raise ValueError("異なるメモの比較はできません。")
    if local is None:
        return "local_missing"
    if local == file_text(remote.text):
        if remote.fingerprint == base.fingerprint:
            return "in_sync"
        return "format_changed" if file_text(remote.text) == file_text(base.text) else "converged"
    local_changed = local != file_text(base.text)
    remote_changed = remote.fingerprint != base.fingerprint
    if local_changed and remote_changed:
        return "conflict"
    if local_changed:
        return "push_pending"
    if remote_changed:
        return "pull_pending"
    return "in_sync"


class Workspace:
    def __init__(self, root, source):
        self.root = Path(root).expanduser().resolve()
        self.meta = self.root / ".memo-sync"
        self.source = source

    def prepare(self):
        self.root.mkdir(parents=True, exist_ok=True)
        for directory in (self.meta, self.meta / "history", self.meta / "reports"):
            if directory.is_symlink():
                raise ValueError("管理ディレクトリへのシンボリックリンクは使用できません。")
            directory.mkdir(exist_ok=True, mode=0o700)
            os.chmod(directory, 0o700)

    @contextmanager
    def lock(self):
        self.prepare()
        fd = os.open(self.meta / "lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        try:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise RuntimeError("別のmemo-syncが処理中です。") from exc
            yield
        finally:
            os.close(fd)

    def state(self):
        path = self.meta / "state.json"
        if not path.exists():
            return {"version": 1, "notes": {}}
        state = json.loads(read_text(path))
        if state.get("version") != 1 or not isinstance(state.get("notes"), dict):
            raise ValueError("管理状態の形式が不正です。")
        return state

    def note_path(self, name):
        if not isinstance(name, str) or Path(name).name != name or name in ("", ".", ".."):
            raise ValueError("登録ファイル名が不正です。")
        return self.root / name

    def snapshot(self, note):
        directory = self.meta / "history" / digest(note.id)
        if directory.is_symlink():
            raise ValueError("原本保存先へのシンボリックリンクは使用できません。")
        directory.mkdir(mode=0o700, exist_ok=True)
        path = directory / (note.fingerprint + ".json")
        if path.exists():
            existing = Note.parse(json.loads(read_text(path)))
            if existing.fingerprint != note.fingerprint:
                raise ValueError("保存した原本とメモが一致しません。")
        else:
            write_new(path, json.dumps(asdict(note), ensure_ascii=False, indent=2) + "\n")
        return str(path.relative_to(self.meta))

    def base(self, record):
        relative = Path(record["base"])
        if len(relative.parts) != 3 or relative.parts[0] != "history" or any(
            re.fullmatch(pattern, part) is None for pattern, part in (
                (r"[0-9a-f]{64}", relative.parts[1]),
                (r"[0-9a-f]{64}\.json", relative.parts[2]),
            )
        ):
            raise ValueError("原本への参照が不正です。")
        path = self.meta / relative
        if path.parent.is_symlink():
            raise ValueError("原本保存先へのシンボリックリンクは使用できません。")
        note = Note.parse(json.loads(read_text(path)))
        if relative.parts[1] != digest(note.id) or path.stem != note.fingerprint:
            raise ValueError("原本への参照とメモが一致しません。")
        return note

    def register(self, note_id=None):
        with self.lock():
            note = self.source.read(note_id)
            if note is None:
                raise ValueError("対象のメモが見つかりません。")
            state = self.state()
            if note.id in state["notes"]:
                return self.note_path(state["notes"][note.id]["file"])
            # Preserve the complete source before producing any editable file.
            base = self.snapshot(note)
            title = re.sub(r'[\x00-\x1f/\\:*?"<>|]', "_", note.title).strip(" .")
            title = title.encode("utf-8")[:200].decode("utf-8", errors="ignore") or "Untitled"
            for index in range(100):
                suffix = "" if index == 0 else "--" + digest(note.id)[:8] + ("" if index == 1 else f"-{index}")
                path = self.note_path(title + suffix + ".md")
                try:
                    write_new(path, file_text(note.text))
                    break
                except FileExistsError:
                    continue
            else:
                raise ValueError("既存ファイルと衝突しない名前を選べませんでした。")
            state["notes"][note.id] = {"file": path.name, "base": base}
            atomic_json(self.meta / "state.json", state)
            return path

    def inspect(self, filename=None):
        results = []
        with self.lock():
            for note_id, record in self.state()["notes"].items():
                if filename and record["file"] != Path(filename).name:
                    continue
                base = self.base(record)
                if base.id != note_id:
                    raise ValueError("原本のメモIDが一致しません。")
                path = self.note_path(record["file"])
                try:
                    local = read_text(path)
                except FileNotFoundError:
                    local = None
                remote = self.source.read(note_id)
                # A slow Notes read must not hide an intervening editor save.
                try:
                    local = read_text(path)
                except FileNotFoundError:
                    local = None
                if remote:
                    self.snapshot(remote)
                status = classify(base, local, remote)
                current = remote or base
                result = {
                    "file": path.name, "status": status,
                    "note_id": note_id, "writes_enabled": False,
                    "attachments": current.attachments, "shared": current.shared,
                    "local_diff": list(difflib.unified_diff(
                        file_text(base.text).splitlines(keepends=True),
                        (local or "").splitlines(keepends=True), fromfile="base", tofile="file")),
                    "remote_diff": list(difflib.unified_diff(
                        file_text(base.text).splitlines(keepends=True),
                        file_text(current.text).splitlines(keepends=True), fromfile="base", tofile="Notes")),
                }
                atomic_json(self.meta / "reports" / (digest(note_id) + ".json"), result)
                results.append(result)
        if filename and not results:
            raise ValueError("このファイルは登録されていません。")
        return results


def main(argv=None):
    parser = argparse.ArgumentParser(description="標準メモの登録・原本保全・双方向差分検知。上書き同期は無効です。")
    parser.add_argument("--root", type=Path, default=Path.home() / "Documents/memo")
    parser.add_argument("--bridge-path", type=Path, default=Path(__file__).with_name("notes.js"), help=argparse.SUPPRESS)
    parser.add_argument("--fixture-dir", type=Path, help="テスト用スナップショットを使用。標準メモへ接続しません。")
    commands = parser.add_subparsers(dest="command", required=True)
    register = commands.add_parser("register", help="標準メモで選択した1件を登録")
    register.add_argument("--note-id")
    status = commands.add_parser("status", help="両側の変更と競合を確認")
    status.add_argument("--json", action="store_true")
    diff = commands.add_parser("diff", help="登録したファイルの両側の差分を表示")
    diff.add_argument("file")
    watch = commands.add_parser("watch", help="変更検知を継続。ファイルとメモを上書きしません")
    watch.add_argument("--interval", type=float, default=5)
    args = parser.parse_args(argv)
    source = FixtureNotes(args.fixture_dir) if args.fixture_dir else Notes(args.bridge_path)
    workspace = Workspace(args.root, source)
    try:
        if args.command == "register":
            print(workspace.register(args.note_id))
        elif args.command in ("status", "diff"):
            results = workspace.inspect(args.file if args.command == "diff" else None)
            if args.command == "status" and args.json:
                print(json.dumps(results, ensure_ascii=False, indent=2))
            for result in results:
                if args.command == "diff":
                    print("".join(result["local_diff"] + result["remote_diff"]), end="")
                elif not args.json:
                    print(result["file"] + ": " + result["status"] + " (上書き無効)")
            if not results and args.command == "status" and not args.json:
                print("登録されたメモはありません。")
        else:
            if not math.isfinite(args.interval) or args.interval < 1:
                raise ValueError("確認間隔は1秒以上にしてください。")
            previous = None
            while True:
                results = workspace.inspect()
                signature = json.dumps(results, ensure_ascii=False, sort_keys=True)
                if signature != previous:
                    for result in results:
                        print(result["file"] + ": " + result["status"] + " (上書き無効)", flush=True)
                    previous = signature
                time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("memo-sync: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
