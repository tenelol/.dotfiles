#!/usr/bin/env python3
"""Sync explicitly enrolled text notes, preserving both sides before every update."""

import argparse
from contextlib import contextmanager
from dataclasses import asdict, dataclass
import ctypes
import difflib
import fcntl
import hashlib
import html
from html.parser import HTMLParser
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
import unicodedata


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
    folder_id: str = ""
    folder: tuple = ()
    account: str = ""
    default_account: bool = True

    @classmethod
    def parse(cls, value):
        if not isinstance(value, dict):
            raise ValueError("メモのスナップショットが不正です。")
        if not isinstance(value.get("folder", ()), (list, tuple)):
            raise ValueError("メモのフォルダ属性が不正です。")
        try:
            note = cls(**{**value, "folder": tuple(value.get("folder", ()))})
        except TypeError as error:
            raise ValueError("メモのスナップショットが不正です。") from error
        if not all(isinstance(getattr(note, key), str) for key in
                   ("id", "title", "html", "text", "modified", "folder_id", "account")) or not note.id:
            raise ValueError("メモのスナップショットが不正です。")
        if type(note.attachments) is not int or note.attachments < 0 or type(note.shared) is not bool:
            raise ValueError("メモの属性が不正です。")
        if type(note.default_account) is not bool or not all(isinstance(part, str) for part in note.folder):
            raise ValueError("メモのフォルダ属性が不正です。")
        if len(json.dumps(value, ensure_ascii=False).encode()) > MAX_BYTES:
            raise ValueError("メモが初期版の容量上限を超えています。")
        return note

    @property
    def fingerprint(self):
        content = asdict(self)
        content.pop("modified")  # Timestamp-only housekeeping is not a content edit.
        for key in ("folder_id", "folder", "account", "default_account"):
            content.pop(key)  # Preserve the hashes of existing immutable snapshots.
        return digest(json.dumps(content, ensure_ascii=False, sort_keys=True))


class Notes:
    def __init__(self, bridge):
        self.bridge = bridge
        self.locations = {}

    def read(self, note_id=None):
        request = {"operation": "read", "id": note_id} if note_id else {"operation": "selected"}
        if note_id and self.locations:
            request["locations"] = self.locations
        return self.request(request)

    def replace(self, expected, text):
        return self.request({
            "operation": "replace", "id": expected.id, "expected": asdict(expected),
            "html": render_text(expected, text), "text": file_text(text),
        })

    def list_ids(self):
        return self.request({"operation": "list"})

    def folders(self):
        folders = self.request({"operation": "folders"})
        self.locations = {folder["id"]: folder for folder in folders}
        return folders

    def ensure_folder(self, parts):
        return self.request({"operation": "ensure_folder", "folder": list(parts)})

    def create(self, folder, text):
        return self.request({"operation": "create", "folder": list(folder["path"]),
                             "folder_id": folder["id"], "account": folder["account"],
                             "html": text_html(text), "text": file_text(text)})

    def request(self, request):
        if sys.platform != "darwin":
            raise RuntimeError("標準メモへの接続はmacOSでのみ利用できます。")
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
        if not isinstance(value, dict) or not any(key in value for key in ("note", "ids", "folders", "folder", "error")):
            raise ValueError("標準メモからの応答形式が不正です。")
        if value.get("error"):
            raise RuntimeError(value["error"])
        if request["operation"] in ("folders", "ensure_folder"):
            result = value.get("folders") if request["operation"] == "folders" else [value.get("folder")]
            if not isinstance(result, list):
                raise ValueError("フォルダ一覧の形式が不正です。")
            result = [parse_folder(item) for item in result]
            return result if request["operation"] == "folders" else result[0]
        if request["operation"] == "list":
            ids = value.get("ids")
            if not isinstance(ids, list) or not all(isinstance(item, str) and item for item in ids):
                raise ValueError("メモ一覧の形式が不正です。")
            return list(dict.fromkeys(ids))
        note = Note.parse(value["note"]) if value.get("note") is not None else None
        if request.get("id") and note and note.id != request["id"]:
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

    def replace(self, expected, text):
        current = self.read(expected.id)
        if current != expected:
            raise RuntimeError("書込直前にメモが更新されました。")
        rendered = render_text(expected, text)
        note = Note(expected.id, text.splitlines()[0], rendered, file_text(text),
                    str(time.time_ns()), folder_id=expected.folder_id, folder=expected.folder,
                    account=expected.account, default_account=expected.default_account)
        atomic_json(self.directory / (digest(note.id) + ".json"), asdict(note))
        return note

    def list_ids(self):
        ids = []
        for path in sorted(self.directory.glob("*.json")):
            if path.name in ("selected.json", "folders.json"):
                continue
            note = Note.parse(json.loads(read_text(path)))
            if path.name != digest(note.id) + ".json":
                raise ValueError("fixtureのメモIDが一致しません。")
            ids.append(note.id)
        return ids

    def folders(self):
        path = self.directory / "folders.json"
        if path.exists():
            return [parse_folder(item) for item in json.loads(read_text(path))]
        return [{"id": "fixture-root", "path": [], "account": "fixture-account", "default_account": True}]

    def ensure_folder(self, parts):
        folders = self.folders()
        for index in range(len(parts) + 1):
            path = list(parts[:index])
            if not any(f["path"] == path for f in folders):
                folders.append({"id": "folder-" + uuid.uuid4().hex, "path": path,
                                "account": "fixture-account", "default_account": True})
        atomic_json(self.directory / "folders.json", folders)
        return next(f for f in folders if f["path"] == list(parts))

    def create(self, folder, text):
        note = Note("created-" + uuid.uuid4().hex, text.splitlines()[0], text_html(text),
                    file_text(text), str(time.time_ns()), folder_id=folder["id"],
                    folder=tuple(folder["path"]), account=folder["account"])
        atomic_json(self.directory / (digest(note.id) + ".json"), asdict(note))
        return note


def parse_folder(value):
    if (not isinstance(value, dict) or set(value) != {"id", "path", "account", "default_account"} or
        not isinstance(value["id"], str) or not value["id"] or
        not isinstance(value["account"], str) or not value["account"] or
        not isinstance(value["path"], list) or
        not all(isinstance(part, str) and part for part in value["path"]) or
        type(value["default_account"]) is not bool):
        raise ValueError("フォルダ情報が不正です。")
    return value


class TextHTML(HTMLParser):
    """Accept text paragraphs and the native first-line title style only."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack, self.lines, self.line = [], [], ""
        self.title_styles = set()
        self.break_ended = False

    def handle_starttag(self, tag, attrs):
        if (tag in ("div", "p") and not self.stack and
            attrs in ([], [("style", "white-space: pre-wrap")])):
            self.stack.append(tag)
            self.break_ended = False
        elif tag == "br" and self.stack and not attrs:
            self.lines.append(self.line)
            self.line = ""
            self.break_ended = True
        elif tag in ("b", "h1", "span") and self.stack and not self.lines:
            if tag == "span" and attrs != [("style", "font-size: 24px")]:
                raise ValueError("対応していない書式があります。")
            if tag != "span" and attrs:
                raise ValueError("対応していない書式があります。")
            self.stack.append(tag)
        else:
            raise ValueError("添付・表・箇条書き・本文の装飾は書き戻せません。")

    def handle_endtag(self, tag):
        if not self.stack or self.stack.pop() != tag:
            raise ValueError("メモのHTML構造を安全に読み取れません。")
        if not self.stack:
            if not self.break_ended:
                self.lines.append(self.line)
            self.line = ""

    def handle_data(self, data):
        if self.stack:
            self.line += data
            if not self.lines and data.strip():
                style = "h1" if "h1" in self.stack or "span" in self.stack else "b" if "b" in self.stack else ""
                self.title_styles.add(style)
            if data:
                self.break_ended = False
        elif data.strip():
            raise ValueError("段落外の本文は書き戻せません。")

    def handle_comment(self, data):
        raise ValueError("対応していないHTMLがあります。")


def text_style(note):
    if note.attachments or note.shared:
        raise ValueError("添付または共有を含むメモは書き戻せません。")
    parser = TextHTML()
    parser.feed(note.html)
    parser.close()
    if parser.stack or "".join(line + "\n" for line in parser.lines) != file_text(note.text):
        raise ValueError("HTMLと本文の一致を確認できないため、書き戻しを停止しました。")
    if len(parser.title_styles) > 1:
        raise ValueError("タイトルの部分的な装飾は書き戻せません。")
    return next(iter(parser.title_styles), "")


def render_text(note, text):
    return text_html(text, text_style(note))


def text_html(text, style=""):
    text = file_text(text)
    if not text.strip() or any(ord(c) < 32 and c not in "\n\t" for c in text):
        raise ValueError("空の本文・制御文字は書き戻せません。")
    lines = text[:-1].split("\n")
    rendered = []
    for index, line in enumerate(lines):
        value = html.escape(line) if line else "<br>"
        if index == 0 and style:
            value = "<" + style + ">" + value + "</" + style + ">"
        # Notes otherwise collapses indentation, repeated spaces, and tabs.
        rendered.append('<div style="white-space: pre-wrap">' + value + "</div>")
    result = "\n".join(rendered)
    if len(result.encode("utf-8")) > MAX_BYTES:
        raise ValueError("書き戻すHTMLが容量上限を超えています。")
    return result


def swap_file(path, staging):
    """Atomically retain the displaced file, including an intervening editor save."""
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == "darwin":
        swap, directory = libc.renameatx_np, -2
    elif sys.platform.startswith("linux"):
        swap, directory = libc.renameat2, -100
    else:
        raise RuntimeError("このOSでは安全なファイル更新を利用できません。")
    swap.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    swap.restype = ctypes.c_int
    if swap(directory, os.fsencode(path), directory, os.fsencode(staging), 2):
        raise OSError(ctypes.get_errno(), "ファイルの交換に失敗しました。")


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
    sync_directory(path.parent)


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def atomic_json(path, value):
    temporary = path.with_name("." + path.name + "." + uuid.uuid4().hex)
    write_new(temporary, json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    try:
        if path.is_symlink():
            raise ValueError("管理ファイルへのシンボリックリンクは使用できません。")
        os.replace(temporary, path)
        sync_directory(path.parent)
    finally:
        temporary.unlink(missing_ok=True)


def classify(base, local, remote):
    if remote is None:
        return "remote_missing"
    if remote.id != base.id:
        raise ValueError("異なるメモの比較はできません。")
    if local is None:
        return "local_missing"
    local = file_text(local)
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
        self.observed = {}

    def prepare(self):
        self.root.mkdir(parents=True, exist_ok=True)
        for directory in (self.meta, self.meta / "history", self.meta / "reports",
                          self.meta / "local-history", self.meta / "operations"):
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
        if (not isinstance(state, dict) or state.get("version") != 1 or
            not isinstance(state.get("notes"), dict) or type(state.get("discover", False)) is not bool):
            raise ValueError("管理状態の形式が不正です。")
        if any(key in state and not isinstance(state[key], dict) for key in ("folders", "creates")):
            raise ValueError("ディレクトリの管理状態が不正です。")
        for note_id, record in state["notes"].items():
            if (not isinstance(note_id, str) or not note_id or not isinstance(record, dict) or
                not isinstance(record.get("base"), str) or
                type(record.get("sync_enabled", False)) is not bool or
                type(record.get("pull_enabled", False)) is not bool):
                raise ValueError("登録の管理状態が不正です。")
            self.note_path(record.get("file"))
            pending = record.get("pending")
            if pending is not None and (
                not isinstance(pending, dict) or
                pending.get("direction") not in ("push_pending", "pull_pending") or
                any(not isinstance(pending.get(key), str) or re.fullmatch(pattern, pending[key]) is None
                    for key, pattern in (("operation", r"[0-9a-f]{32}"),
                                         ("target", r"[0-9a-f]{64}"), ("local", r"[0-9a-f]{64}")))
            ):
                raise ValueError("同期処理の記録が不正です。")
        for name, folder in state.get("folders", {}).items():
            if self.folder_name(parse_folder(folder)) != name:
                raise ValueError("フォルダの管理状態が不正です。")
        for name, marker in state.get("creates", {}).items():
            self.note_path(name)
            if (not isinstance(marker, dict) or
                not isinstance(marker.get("error"), str) or
                not re.fullmatch(r"[0-9a-f]{32}", marker.get("operation", "")) or
                not re.fullmatch(r"[0-9a-f]{64}", marker.get("local", ""))):
                raise ValueError("作成処理の管理状態が不正です。")
            parse_folder(marker["folder"])
        return state

    def note_path(self, name):
        if (not isinstance(name, str) or name in ("", ".", "..") or Path(name).is_absolute() or
            Path(name).as_posix() != name or "\\" in name or
            any(part in (".", "..") or part.startswith(".") or any(ord(c) < 32 for c in part)
                for part in Path(name).parts)):
            raise ValueError("登録ファイル名が不正です。")
        path = self.root
        for index, part in enumerate(Path(name).parts):
            path = path / part
            if path.is_symlink():
                raise OSError("メモのパスへのシンボリックリンクは使用できません。")
            if index < len(Path(name).parts) - 1 and path.exists() and not path.is_dir():
                raise ValueError("メモの親パスがディレクトリではありません。")
        return path

    def filename(self, value):
        path = Path(value)
        if path.is_absolute():
            path = path.relative_to(self.root)
        self.note_path(path.as_posix())
        return path.as_posix()

    def folder_name(self, folder):
        parts = folder["path"]
        if not folder["default_account"]:
            parts = ["_accounts", digest(folder["account"])[:8], *parts]
        if parts:
            self.note_path("/".join(parts) + "/__guard__")
        return unicodedata.normalize("NFC", "/".join(parts))

    def remember_folder(self, state, folder):
        name = self.folder_name(folder)
        known = state.setdefault("folders", {})
        if any(old["id"] == folder["id"] and key != name for key, old in known.items()):
            raise ValueError("フォルダの移動・改名を検知しました。自動作成を停止しています。")
        path = self.root if not name else self.note_path(name + "/__guard__").parent
        if name in known and (known[name]["id"] != folder["id"] or not path.is_dir()):
            raise ValueError("登録済みフォルダの削除・入れ替えを検知しました。")
        path.mkdir(parents=True, exist_ok=True, mode=0o700)
        for other in known:
            other_path = self.root if not other else self.note_path(other + "/__guard__").parent
            if other != name and other_path.exists() and os.path.samefile(path, other_path):
                raise ValueError("同じローカルディレクトリに別のフォルダが対応しています。")
        known[name] = folder
        return path

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

    def register(self, note_id=None, sync=False):
        with self.lock():
            note = self.source.read(note_id)
            if note is None:
                raise ValueError("対象のメモが見つかりません。")
            state = self.state()
            path = self.add(state, note)
            if sync:
                self.try_enroll(state, note, path)
            return path

    def add(self, state, note):
        if note.id in state["notes"]:
            return self.note_path(state["notes"][note.id]["file"])
        # Preserve the complete source before producing any editable file.
        base = self.snapshot(note)
        folder = {"id": note.folder_id, "path": list(note.folder),
                  "account": note.account, "default_account": note.default_account}
        directory = self.remember_folder(state, folder) if note.folder_id else self.root
        title = re.sub(r'[\x00-\x1f/\\:*?"<>|]', "_", note.title).strip(" .")
        title = title.encode("utf-8")[:200].decode("utf-8", errors="ignore") or "Untitled"
        for index in range(100):
            suffix = "" if index == 0 else "--" + digest(note.id)[:8] + ("" if index == 1 else f"-{index}")
            path = directory / (title + suffix + ".md")
            filename = path.relative_to(self.root).as_posix()
            self.note_path(filename)
            if any(record["file"] == filename for record in state["notes"].values()):
                continue  # A missing file still belongs to its original note.
            try:
                write_new(path, file_text(note.text))
                break
            except FileExistsError:
                continue
        else:
            raise ValueError("既存ファイルと衝突しない名前を選べませんでした。")
        state["notes"][note.id] = {"file": filename, "base": base, "folder_id": note.folder_id,
                                  "remote_directory": directory.relative_to(self.root).as_posix()}
        atomic_json(self.meta / "state.json", state)
        return path

    def import_all(self, enable=False):
        with self.lock():
            state = self.state()
            if not enable and not state.get("discover"):
                return {}
            ids = self.source.list_ids()
            errors = {}
            added = 0
            for note_id in ids:
                if note_id in state["notes"] and not enable:
                    continue  # Respect an explicit disable of an existing registration.
                try:
                    note = self.source.read(note_id)
                    if note is None:
                        continue
                    new = note_id not in state["notes"]
                    path = self.add(state, note)
                    record = state["notes"][note_id]
                    try:
                        self.enroll(state, note, path)
                    except ValueError as error:
                        record["sync_enabled"] = False
                        record["pull_enabled"] = True
                        record["write_blocked"] = str(error)
                    added += int(new)
                    atomic_json(self.meta / "state.json", state)
                except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                    errors[note_id] = str(error)
            state["discover"] = True
            atomic_json(self.meta / "state.json", state)
            atomic_json(self.meta / "import-errors.json", errors)
            return {"found": len(ids), "registered": len(state["notes"]), "added": added,
                    "bidirectional": sum(bool(r.get("sync_enabled")) for r in state["notes"].values()),
                    "pull_only": sum(not r.get("sync_enabled", False) and bool(r.get("pull_enabled"))
                                     for r in state["notes"].values()),
                    "errors": errors}

    def discover_local(self, stable=False):
        """Add folders and nonempty files; never infer a move or retry an ambiguous create."""
        with self.lock():
            state = self.state()
            errors = {}
            catalog = self.source.folders()
            folders = {}
            for folder in catalog:
                name = None
                try:
                    name = self.folder_name(folder)
                    folders[name] = folder
                    self.remember_folder(state, folder)
                except (OSError, ValueError) as error:
                    errors[name if name is not None else folder["id"]] = str(error)
            known = state.setdefault("folders", {})
            if "" in known and "" in folders and known[""]["id"] != folders[""]["id"]:
                errors[""] = "既定アカウントまたはフォルダが変わっています。"
            files = []
            for parent, directories, names in os.walk(self.root, followlinks=False):
                directories[:] = [name for name in directories if not name.startswith(".") and
                                   name != "_accounts" and not (Path(parent) / name).is_symlink()]
                name = Path(parent).relative_to(self.root).as_posix()
                name = "" if name == "." else name
                name = unicodedata.normalize("NFC", name)
                if name not in known and name not in errors and "" not in errors:
                    try:
                        # Existing folder names are reused; duplicate/shared destinations are rejected.
                        folder = self.source.ensure_folder(Path(name).parts if name else ())
                        self.remember_folder(state, folder)
                        folders[name] = folder
                    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                        errors[name] = str(error)
                if name in errors or name not in folders:
                    continue
                files.extend(Path(parent) / name for name in names if name.endswith(".md"))
            atomic_json(self.meta / "state.json", state)
            mapped = {record["file"] for record in state["notes"].values()}
            missing = [record for record in state["notes"].values()
                       if not self.note_path(record["file"]).exists()]
            pending = state.setdefault("creates", {})
            for path in files:
                filename = path.relative_to(self.root).as_posix()
                if filename in mapped or filename in pending:
                    continue
                try:
                    self.note_path(filename)
                    if any(self.note_path(name).exists() and os.path.samefile(path, self.note_path(name))
                           for name in mapped):
                        continue  # Case-only aliases and hard links are not a new note.
                    text = read_text(path)
                    if not text.strip():
                        continue  # A touched file waits for its first real save.
                    signature = digest(text)
                    key = "create:" + filename
                    settled = self.observed.get(key) == signature
                    self.observed[key] = signature
                    if stable and not settled:
                        continue
                    if any(Path(record["file"]).name == path.name or
                           file_text(self.base(record).text) == file_text(text) for record in missing):
                        raise ValueError("既存メモの移動候補です。新規メモとして複製しません。")
                    text_html(text)  # Validate before recording or touching Notes.
                    backup = self.meta / "local-history" / (signature + ".txt")
                    if not backup.exists():
                        write_new(backup, text)
                    elif read_text(backup) != text:
                        raise ValueError("作成前のファイル履歴が一致しません。")
                    folder = folders[unicodedata.normalize("NFC", path.parent.relative_to(self.root).as_posix())
                                     if path.parent != self.root else ""]
                    operation = uuid.uuid4().hex
                    marker = {"operation": operation, "local": signature, "folder": folder,
                              "error": "作成途中です。再作成せず標準メモを確認してください。"}
                    atomic_json(self.meta / "operations" / (operation + ".json"),
                                {"type": "create", "file": filename, **marker,
                                 "local_backup": str(backup.relative_to(self.meta))})
                    pending[filename] = marker
                    atomic_json(self.meta / "state.json", state)
                    if read_text(path) != text:
                        pending.pop(filename)
                        atomic_json(self.meta / "state.json", state)
                        continue
                    note = self.source.create(folder, text)
                    if (not note or file_text(note.text) != file_text(text) or
                        note.folder_id != folder["id"] or note.account != folder["account"]):
                        raise RuntimeError("作成結果の本文またはフォルダが一致しません。再作成を停止しました。")
                    if note.id in state["notes"]:
                        raise RuntimeError("作成結果が既存メモを指しています。")
                    state["notes"][note.id] = {"file": filename, "base": self.snapshot(note),
                                              "folder_id": note.folder_id,
                                              "remote_directory": self.folder_name(folder) or ".",
                                              "sync_enabled": True, "pull_enabled": True}
                    pending.pop(filename)
                    mapped.add(filename)
                    atomic_json(self.meta / "state.json", state)
                except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                    errors[filename] = str(error)
                    if filename in pending:
                        pending[filename]["error"] = str(error)
                        atomic_json(self.meta / "state.json", state)
            atomic_json(self.meta / "directory-errors.json", errors)
            return errors

    def try_enroll(self, state, note, path):
        try:
            self.enroll(state, note, path)
        except ValueError as error:
            print("memo-sync: 登録済み。自動同期は停止: " + str(error), file=sys.stderr)

    def enroll(self, state, note, path):
        text_style(note)
        record = state["notes"][note.id]
        remote_directory = self.folder_name({"path": list(note.folder), "account": note.account,
                                             "default_account": note.default_account})
        if record.get("remote_directory", ".") != (remote_directory or "."):
            raise ValueError("フォルダの移動を検知しました。同期の再開には確認が必要です。")
        local = read_text(path)
        status = classify(self.base(record), local, note)
        if status == "conflict" or (record.get("pending") and file_text(local) != file_text(note.text)):
            raise ValueError("両側の変更を確認し、本文を一致させてから有効化してください。")
        if file_text(local) == file_text(note.text):
            record["base"] = self.snapshot(note)
            record.pop("pending", None)
        record["sync_enabled"] = True
        record["pull_enabled"] = True
        record.pop("write_blocked", None)
        atomic_json(self.meta / "state.json", state)

    def enable(self, filename, enabled=True):
        with self.lock():
            state = self.state()
            for note_id, record in state["notes"].items():
                if record["file"] == self.filename(filename):
                    if not enabled:
                        record["sync_enabled"] = False
                        record["pull_enabled"] = False
                        atomic_json(self.meta / "state.json", state)
                        return
                    note = self.source.read(note_id)
                    if note is None:
                        raise ValueError("対象のメモが見つかりません。")
                    self.enroll(state, note, self.note_path(record["file"]))
                    return
            raise ValueError("このファイルは登録されていません。")

    def sync_note(self, state, record, path, local, remote, status):
        target = file_text(local) if status == "push_pending" else file_text(remote.text)
        if status == "push_pending":
            render_text(remote, local)  # Reject unsupported contents before journaling.
        local_backup = self.meta / "local-history" / (digest(local) + ".txt")
        if local_backup.exists():
            if read_text(local_backup) != local:
                raise ValueError("保存したファイル原本が一致しません。")
        else:
            write_new(local_backup, local)
        operation = uuid.uuid4().hex
        record["pending"] = {
            "operation": operation, "direction": status, "target": digest(target),
            "local": digest(local),
        }
        atomic_json(self.meta / "operations" / (operation + ".json"), {
            **record["pending"], "file": record["file"], "note_id": remote.id,
            "local_backup": str(local_backup.relative_to(self.meta)),
            "remote_backup": self.snapshot(remote),
        })
        # A durable marker makes a timeout/crash fail closed on the next run.
        atomic_json(self.meta / "state.json", state)
        if read_text(path) != local:
            raise RuntimeError("同期直前にファイルが更新されました。履歴を確認してください。")
        if status == "push_pending":
            updated = self.source.replace(remote, local)
            if updated is None or updated.id != remote.id or file_text(updated.text) != target:
                raise RuntimeError("書き戻した本文が一致しません。原本を保全して同期を停止しました。")
            self.snapshot(updated)
            if read_text(path) != local:
                raise RuntimeError("書込中にファイルが更新されました。同期を停止しました。")
        else:
            updated = self.source.read(remote.id)
            if updated != remote:
                raise RuntimeError("同期直前にメモが更新されました。同期を停止しました。")
            staging = self.meta / "local-history" / (operation + "-displaced.txt")
            write_new(staging, target)
            swap_file(path, staging)
            sync_directory(path.parent)
            sync_directory(staging.parent)
            # The displaced inode stays in history even if an editor saved at the swap.
            if read_text(staging) != local:
                raise RuntimeError("ファイル交換中に編集されました。displaced.txtに編集内容を保全しました。")
            if read_text(path) != target:
                raise RuntimeError("ファイル更新後に編集されました。同期を停止しました。")
        record["base"] = self.snapshot(updated)
        record.pop("pending")
        atomic_json(self.meta / "state.json", state)
        return updated

    def inspect(self, filename=None, sync=False, stable=False):
        results = []
        with self.lock():
            state = self.state()
            for note_id, record in state["notes"].items():
                if filename and record["file"] != self.filename(filename):
                    continue
                baseline = record["base"]
                base = self.base(record)
                if base.id != note_id:
                    raise ValueError("原本のメモIDが一致しません。")
                path = self.note_path(record["file"])
                try:
                    local = read_text(path)
                except FileNotFoundError:
                    local = None
                read_error = None
                try:
                    remote = self.source.read(note_id)
                except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
                    remote = None
                    read_error = str(exc)
                # A slow Notes read must not hide an intervening editor save.
                try:
                    local = read_text(path)
                except FileNotFoundError:
                    local = None
                if remote:
                    self.snapshot(remote)
                status = "unavailable" if read_error else classify(base, local, remote)
                if remote and "folder_id" not in record:
                    record["folder_id"] = remote.folder_id
                    record["remote_directory"] = self.folder_name({
                        "path": list(remote.folder), "account": remote.account,
                        "default_account": remote.default_account}) or "."
                    atomic_json(self.meta / "state.json", state)
                if remote and record.get("folder_id") and remote.folder_id != record["folder_id"]:
                    status = "folder_changed"
                if remote and record.get("remote_directory", ".") != (self.folder_name({
                    "path": list(remote.folder), "account": remote.account,
                    "default_account": remote.default_account}) or "."):
                    status = "folder_changed"
                error = read_error
                enabled = record.get("sync_enabled", False)
                pull_enabled = record.get("pull_enabled", False)
                signature = (local, remote.fingerprint if remote else None)
                settled = self.observed.get(note_id) == signature
                self.observed[note_id] = signature
                pending = record.get("pending")
                if pending:
                    # Resume only a fully verified completed operation, never retry a write blindly.
                    displaced_ok = True
                    if pending["direction"] == "pull_pending":
                        displaced = self.meta / "local-history" / (pending["operation"] + "-displaced.txt")
                        displaced_ok = displaced.exists() and digest(read_text(displaced)) == pending["local"]
                    if (sync and not pending.get("error") and displaced_ok and remote and local is not None and
                        digest(file_text(local)) == pending["target"] and
                        file_text(local) == file_text(remote.text)):
                        record["base"] = self.snapshot(remote)
                        record.pop("pending")
                        atomic_json(self.meta / "state.json", state)
                        status = "in_sync"
                    else:
                        status = "interrupted"
                        error = pending.get("error", "中断された同期があります。原本・ファイル履歴を確認してください。")
                elif (sync and (enabled or pull_enabled) and remote and local is not None and
                      (not stable or settled)):
                    try:
                        if status == "pull_pending" or (status == "push_pending" and enabled):
                            remote = self.sync_note(state, record, path, local, remote, status)
                            status = "in_sync"
                        elif status in ("converged", "format_changed"):
                            record["base"] = self.snapshot(remote)
                            atomic_json(self.meta / "state.json", state)
                            status = "in_sync"
                    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
                        error = str(exc)
                        if record.get("pending"):
                            record["pending"]["error"] = error
                            atomic_json(self.meta / "state.json", state)
                        status = "interrupted" if record.get("pending") else "unsupported"
                if record["base"] != baseline:
                    base = self.base(record)
                    local = read_text(path)
                current = remote or base
                result = {
                    "file": record["file"], "status": status,
                    "note_id": note_id, "writes_enabled": enabled, "error": error,
                    "pull_enabled": pull_enabled, "write_blocked": record.get("write_blocked"),
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
            for name, pending in state.get("creates", {}).items():
                if not filename or name == self.filename(filename):
                    results.append({"file": name, "status": "create_interrupted", "note_id": None,
                                    "writes_enabled": False, "pull_enabled": False,
                                    "error": pending["error"], "local_diff": [], "remote_diff": []})
        if filename and not results:
            raise ValueError("このファイルは登録されていません。")
        return results


def main(argv=None):
    parser = argparse.ArgumentParser(prog="memo-sync", description="標準メモとファイルの双方向同期。明示的に有効化したメモのみ更新します。")
    parser.add_argument("--root", type=Path, default=Path.home() / "Documents/memo")
    parser.add_argument("--bridge-path", type=Path, default=Path(__file__).with_name("notes.js"), help=argparse.SUPPRESS)
    parser.add_argument("--fixture-dir", type=Path, help="テスト用スナップショットを使用。標準メモへ接続しません。")
    commands = parser.add_subparsers(dest="command", required=True)
    register = commands.add_parser("register", help="標準メモで選択した1件を登録")
    register.add_argument("--note-id")
    register.add_argument("--sync", action="store_true", help="対応するテキストメモの自動同期も有効化")
    commands.add_parser("import-all", help="全メモを登録し、新規メモの自動取込も有効化")
    for command in ("enable", "disable"):
        enrollment = commands.add_parser(command, help="登録ファイルの自動同期を" + ("有効化" if command == "enable" else "停止"))
        enrollment.add_argument("file")
    status = commands.add_parser("status", help="両側の変更と競合を確認")
    status.add_argument("--json", action="store_true")
    diff = commands.add_parser("diff", help="登録したファイルの両側の差分を表示")
    diff.add_argument("file")
    sync = commands.add_parser("sync", help="有効化したメモを一度双方向同期")
    sync.add_argument("file", nargs="?")
    sync.add_argument("--json", action="store_true")
    watch = commands.add_parser("watch", help="有効化したメモの双方向同期を継続")
    watch.add_argument("--interval", type=float, default=5)
    args = parser.parse_args(argv)
    source = FixtureNotes(args.fixture_dir) if args.fixture_dir else Notes(args.bridge_path)
    workspace = Workspace(args.root, source)
    try:
        if args.command == "register":
            print(workspace.register(args.note_id, args.sync))
        elif args.command == "import-all":
            result = workspace.import_all(enable=True)
            print(json.dumps(result, ensure_ascii=False, indent=2))
            return int(bool(result["errors"]))
        elif args.command in ("enable", "disable"):
            workspace.enable(args.file, args.command == "enable")
        elif args.command in ("status", "diff", "sync"):
            if args.command == "sync" and not args.file:
                workspace.discover_local()
            results = workspace.inspect(args.file if args.command in ("diff", "sync") else None,
                                        sync=args.command == "sync")
            if args.command != "diff" and args.json:
                print(json.dumps(results, ensure_ascii=False, indent=2))
            for result in results:
                if args.command == "diff":
                    print("".join(result["local_diff"] + result["remote_diff"]), end="")
                elif not args.json:
                    print_result(result)
            if not results and args.command != "diff" and not args.json:
                print("登録されたメモはありません。")
            if args.command == "sync" and any(r["status"] in ("conflict", "interrupted", "unsupported",
                                                            "local_missing", "remote_missing", "unavailable",
                                                            "folder_changed", "create_interrupted") for r in results):
                return 1
            if any(r["status"] == "unavailable" for r in results):
                return 1
        else:
            if not math.isfinite(args.interval) or args.interval < 1:
                raise ValueError("確認間隔は1秒以上にしてください。")
            previous = None
            previous_error = None
            next_discovery = 0
            while True:
                try:
                    if time.monotonic() >= next_discovery:
                        workspace.import_all()
                        next_discovery = time.monotonic() + 30
                    workspace.discover_local(stable=True)
                    results = workspace.inspect(sync=True, stable=True)
                except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                    # ponytail: one watcher per workspace; a busy foreground command waits one poll.
                    if str(error) != previous_error:
                        print("memo-sync: " + str(error), file=sys.stderr, flush=True)
                    previous_error = str(error)
                    time.sleep(args.interval)
                    continue
                previous_error = None
                signature = json.dumps(results, ensure_ascii=False, sort_keys=True)
                if signature != previous:
                    for result in results:
                        print_result(result)
                    previous = signature
                time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("memo-sync: " + str(error), file=sys.stderr)
        return 1
    return 0


def print_result(result):
    label = "双方向同期" if result["writes_enabled"] else "メモ→ファイル" if result["pull_enabled"] else "同期無効"
    print(result["file"] + ": " + result["status"] + " (" + label + ")", flush=True)
    if result["error"]:
        print("memo-sync: " + result["error"], file=sys.stderr, flush=True)


if __name__ == "__main__":
    raise SystemExit(main())
