#!/usr/bin/env python3
"""Sync explicitly enrolled text notes, preserving both sides before every update."""

import argparse
from contextlib import contextmanager
from dataclasses import asdict, dataclass, replace
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
import string
import subprocess
import sys
import time
import uuid
import unicodedata
from notes_text import DeferredSync


MAX_BYTES = 16 * 1024 * 1024
SAVE_SETTLE_SECONDS = 0.35
DELETE_SETTLE_SECONDS = 2


class MissingStateError(ValueError):
    """Existing files cannot be safely identified without the mapping state."""


def digest(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def file_text(value):
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    return value if not value or value.endswith("\n") else value + "\n"


def content_key(text):
    return re.sub(r"\s+", "", text)


def image_plain(text):
    return file_text(text.replace("\ufffc", ""))


def is_note_file(name):
    path = Path(name)
    return not path.name.startswith(".") and path.suffix.lower() in ("", ".md")


def retitle(text, title, markdown):
    title = unicodedata.normalize("NFC", title)
    if not title.strip() or any(ord(c) < 32 or c in "\u2028\u2029" for c in title):
        raise ValueError("タイトルには空文字や改行を使用できません。")
    first, _, body = file_text(text).partition("\n")
    prefix = re.match(r"^(#{1,6})[ \t]+", first) if markdown else None
    if markdown:
        title = re.sub("([" + re.escape(string.punctuation) + "])", r"\\\1", title)
    return (prefix.group() if prefix else "") + title + "\n" + body


def validate_images(note):
    from bs4 import BeautifulSoup
    soup = BeautifulSoup(note.html, "html.parser")
    images = soup.find_all("img")
    if (note.shared or len(images) != note.attachments or
        soup.find(["table", "object", "audio", "video"]) or
        any(not re.match(r"^data:image/(png|jpeg|gif);base64,", image.get("src", "")) for image in images)):
        raise ValueError("この添付形式は画像を保持した本文編集に対応していません。")


def markdown_html(text):
    import mistune
    from bs4 import BeautifulSoup
    ast = mistune.create_markdown(renderer="ast", plugins=["table", "task_lists", "strikethrough"])(text)
    allowed = {"heading", "paragraph", "blank_line", "text", "strong", "emphasis",
               "codespan", "block_code", "list", "list_item", "block_text", "softbreak", "linebreak",
               "table", "table_head", "table_body", "table_row", "table_cell"}

    def check(nodes):
        for node in nodes:
            if (node["type"] not in allowed or
                (node["type"] == "list" and node.get("attrs", {}).get("ordered")) or
                (node["type"] == "heading" and node.get("attrs", {}).get("level", 1) > 2)):
                raise ValueError("リンク・番号付きリスト・画像・HTMLなどは、書式を保持できないため停止します。")
            check(node.get("children", []))

    check(ast)
    if not text.strip() or any(ord(c) < 32 and c not in "\n\t\r" for c in text):
        raise ValueError("空のMarkdown・制御文字は書き戻せません。")
    soup = BeautifulSoup(mistune.html(text), "html.parser")
    for tag in soup.find_all(["p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "li", "td", "th"]):
        tag["style"] = "white-space: pre-wrap"
    result = str(soup)
    if len(result.encode()) > MAX_BYTES:
        raise ValueError("MarkdownのHTMLが容量上限を超えています。")
    return result, content_key(soup.get_text())


def markdown_text(note):
    from bs4 import BeautifulSoup
    from markdownify import markdownify
    soup = BeautifulSoup(note.html, "html.parser")
    tables = soup.find_all("table")
    if note.shared or note.attachments != len(tables):
        raise ValueError("表以外の添付・共有を含むメモはMarkdownで書き戻せません。")
    full_key = content_key(soup.get_text())
    outside = "".join(t for t in soup.find_all(string=True) if not t.find_parent("table"))
    if (content_key(outside) != content_key(note.text.replace("\ufffc", "")) or
        note.text.count("\ufffc") != len(tables)):
        raise ValueError("HTMLと全文の一致を確認できないため停止しました。")
    for wrapper in list(soup.find_all("object")):
        if len(wrapper.find_all("table")) != 1 or any(
            t.strip() for t in wrapper.find_all(string=True) if not t.find_parent("table")
        ):
            raise ValueError("表以外のオブジェクトは書き戻せません。")
        wrapper.unwrap()
    for table in tables:
        if table.find_parent("table"):
            raise ValueError("入れ子の表は書き戻せません。")
        rows = table.find_all("tr")
        widths = {len(row.find_all(["td", "th"], recursive=False)) for row in rows}
        if not rows or len(widths) != 1 or 0 in widths or table.find(attrs={"rowspan": True}) or table.find(attrs={"colspan": True}):
            raise ValueError("結合セルや不均一な列数の表は書き戻せません。")
        for tag in table.find_all(True) + [table]:
            if tag.name in ("table", "tbody", "thead", "tr", "td", "th"):
                if set(tag.attrs) - {"style", "cellspacing", "cellpadding", "valign", "align"}:
                    raise ValueError("未対応の表属性があります。")
                tag.attrs = {}
            elif tag.name == "font" and tag.get("face", "").startswith(".Hira"):
                tag.unwrap()
        for cell in rows[0].find_all(["td", "th"], recursive=False):
            cell.name = "th"
    allowed = {"div", "p", "br", "b", "strong", "i", "em", "span", "ul", "li",
               "h1", "h2", "h3", "h4", "h5", "h6", "pre", "code", "tt", "font",
               "table", "thead", "tbody", "tr", "td", "th"}
    for tag in soup.find_all(True):
        if tag.name not in allowed:
            raise ValueError("このメモの書式はMarkdown往復に対応していません。")
        for key, value in tag.attrs.items():
            if key == "face" and tag.name == "font" and value in ("Courier", "Menlo", "Monaco"):
                continue
            if key == "style" and re.fullmatch(r"(font-size:\s*(?:24|18|16|14|13|12)px|white-space:\s*pre-wrap);?", value):
                continue
            raise ValueError("このメモの属性はMarkdown往復に対応していません。")
    for block in list(soup.find_all(["div", "p"])):
        fonts = block.find_all("font")
        spans = block.find_all("span")
        if (fonts and not any(re.fullmatch(r"font-size:\s*13px;?", tag.get("style", "")) for tag in spans) and
            block.get_text() == "".join(tag.get_text() for tag in fonts) and
            all(tag.get("face") in ("Courier", "Menlo", "Monaco") for tag in fonts)):
            block.name = "pre"
            block.clear()
            # Use the original native text, including indentation and tabs.
            block.string = "\n".join(font.get_text() for font in fonts)
        elif spans and all(re.fullmatch(r"font-size:\s*(24|18|16)px;?", tag.get("style", "")) for tag in spans):
            size = re.search(r"\d+", spans[0]["style"]).group()
            value = block.get_text()
            block.name = "h1" if size == "24" else "h2"
            block.clear()
            block.string = value
        elif block.name == "div":
            block.name = "p"
        if block.contents and getattr(block.contents[-1], "name", None) == "br":
            block.contents[-1].decompose()
    for tag in list(soup.find_all(["span", "font"])):
        tag.unwrap()
    for tag in soup.find_all("tt"):
        tag.name = "code"
    value = file_text(markdownify(str(soup), heading_style="ATX", bullets="-", code_language=""))
    _, key = markdown_html(value)
    if key != full_key:
        raise ValueError("Markdown変換で本文が変化したため停止しました。")
    return value


def verify_markdown(note, text):
    import mistune
    converted = markdown_text(note)

    def code_content(value):
        inline, blocks = [], []

        def visit(nodes):
            for node in nodes:
                if node["type"] == "codespan":
                    inline.append(node["raw"])
                elif node["type"] == "block_code":
                    blocks.append(node["raw"].rstrip("\n"))
                visit(node.get("children", []))

        visit(mistune.create_markdown(renderer="ast")(value))
        return inline, "\n".join(blocks)

    if code_content(text) != code_content(converted):
        raise ValueError("コードの空白・インデントが変化したため同期を停止しました。")
    if markdown_html(text)[1] != markdown_html(converted)[1]:
        raise ValueError("Markdownの全文が一致しません。")
    from bs4 import BeautifulSoup
    def cells(value):
        soup = BeautifulSoup(markdown_html(value)[0], "html.parser")
        return [[[c.get_text().strip("\n") for c in r.find_all(["th", "td"], recursive=False)]
                 for r in t.find_all("tr")] for t in soup.find_all("table")]
    if cells(text) != cells(converted):
        raise ValueError("表の行・列・セル内容が一致しません。")
    return converted


def markdown_matches(note, text):
    try:
        verify_markdown(note, text)
        return True
    except ValueError:
        return False


def table_count(html_text):
    return len(re.findall(r"<table(?:\s|>)", html_text, flags=re.I))


def literal_text(note):
    from bs4 import BeautifulSoup
    if note.shared or note.attachments or BeautifulSoup(note.html, "html.parser").find(
        ["img", "table", "object", "audio", "video", "iframe"]
    ):
        raise ValueError("原文同期中のメモに添付・表・共有が追加されたため停止しました。")
    return file_text(note.text)


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

    def replace(self, expected, text, markdown=False, literal=False):
        if literal:
            (markdown_text(expected) if table_count(expected.html) else literal_text(expected))
            rendered, key = text_html(text), None
        elif markdown:
            markdown_text(expected)
            rendered, key = markdown_html(text)
        else:
            rendered, key = render_text(expected, text), None
        return self.request({
            "operation": "replace", "id": expected.id, "expected": asdict(expected),
            "html": rendered, "text": file_text(text), "content_key": key,
            "tables_before": table_count(expected.html) if markdown or literal else 0,
            "tables_after": table_count(rendered) if markdown else 0,
        })

    def replace_images(self, expected, text):
        from notes_text import NotesText, image_layout_key
        validate_images(expected)
        target = image_plain(text)
        if not target.strip() or any(ord(c) < 32 and c not in "\n\t" for c in target):
            raise ValueError("空の本文・制御文字は書き戻せません。")
        ui = lambda: self.request({"operation": "ui_state", "id": expected.id})
        before = ui()
        if before["foreground"] == "com.apple.Notes":
            raise DeferredSync("標準メモを操作中のため、画像付きメモの書き戻しを待機しています。")
        editor = NotesText()
        def selected():
            value = ui()
            return value["selected"] == expected.id and value["foreground"] != "com.apple.Notes"
        try:
            editor.select(expected.title, selected)
            if self.read(expected.id) != expected or ui()["attachments"] != before["attachments"]:
                raise DeferredSync("書込直前にメモが変わったため再確認します。")
            expected_text = editor.replace(expected.text, target, selected)
            updated = self.read(expected.id)
            if (not updated or image_layout_key(updated.text) != image_layout_key(expected_text) or
                ui()["attachments"] != before["attachments"]):
                raise RuntimeError("本文または添付の保持を確認できません。同期を停止しました。")
            return updated
        finally:
            editor.close()

    def list_ids(self):
        return self.request({"operation": "list"})

    def index(self):
        return self.request({"operation": "index"})
    def folders(self):
        folders = self.request({"operation": "folders"})
        self.locations = {folder["id"]: folder for folder in folders}
        return folders

    def ensure_folder(self, parts):
        folder = self.request({"operation": "ensure_folder", "folder": list(parts)})
        self.locations[folder["id"]] = folder
        return folder

    def create(self, folder, text, markdown=False):
        rendered, key = markdown_html(text) if markdown else (text_html(text), None)
        return self.request({"operation": "create", "folder": list(folder["path"]),
                             "folder_id": folder["id"], "account": folder["account"],
                             "html": rendered, "text": file_text(text), "content_key": key,
                             "tables_after": table_count(rendered) if markdown else 0})

    def trash(self, expected):
        return self.request({"operation": "trash", "id": expected.id, "expected": asdict(expected)})

    def move(self, expected, destination):
        return self.request({"operation": "move_note", "id": expected.id,
                             "expected": asdict(expected), "destination": destination})

    def delete_folder(self, expected):
        return self.request({"operation": "delete_folder", "expected": expected})

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
        if not isinstance(value, dict) or not any(key in value for key in ("note", "ids", "index", "folders", "folder", "deleted", "ui", "error")):
            raise ValueError("標準メモからの応答形式が不正です。")
        if value.get("error"):
            raise RuntimeError(value["error"])
        if request["operation"] == "ui_state":
            result = value.get("ui")
            if not isinstance(result, dict) or set(result) != {"selected", "foreground", "attachments"}:
                raise ValueError("画面状態の応答が不正です。")
            return result
        if request["operation"] in ("trash", "delete_folder"):
            if value.get("deleted") is not True:
                raise ValueError("削除結果を確認できません。")
            return True
        if request["operation"] == "index":
            index = value.get("index")
            if (not isinstance(index, dict) or
                not all(isinstance(key, str) and key and isinstance(date, str) and date
                        for key, date in index.items())):
                raise ValueError("更新日時一覧の形式が不正です。")
            return index
        if request["operation"] in ("folders", "ensure_folder"):
            if request["operation"] == "folders":
                locations = value.get("note_locations", {})
                if not isinstance(locations, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in locations.items()):
                    raise ValueError("メモの所属フォルダ一覧が不正です。")
                self.note_locations = locations
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

    def move(self, expected, destination):
        if self.read(expected.id) != expected or not expected.default_account or destination["account"] != expected.account:
            raise RuntimeError("移動前のメモが一致しません。")
        note = replace(expected, folder_id=destination["id"], folder=tuple(destination["path"]))
        atomic_json(self.directory / (digest(note.id) + ".json"), asdict(note))
        return note

    def replace(self, expected, text, markdown=False, literal=False):
        current = self.read(expected.id)
        if current != expected:
            raise RuntimeError("書込直前にメモが更新されました。")
        if literal:
            (markdown_text(expected) if table_count(expected.html) else literal_text(expected))
        rendered = text_html(text) if literal else markdown_html(text)[0] if markdown else render_text(expected, text)
        if markdown:
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(rendered, "html.parser")
            for table in soup.find_all("table"):
                table.replace_with("\ufffc")
            plain = "".join(soup.stripped_strings)
        else:
            plain = file_text(text)
        note = Note(expected.id, text.splitlines()[0], rendered, plain,
                    str(time.time_ns()), attachments=table_count(rendered), folder_id=expected.folder_id, folder=expected.folder,
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

    def index(self):
        return {note_id: Note.parse(json.loads(read_text(self.directory / (digest(note_id) + ".json")))).modified
                for note_id in self.list_ids()}

    def folders(self):
        path = self.directory / "folders.json"
        self.note_locations = {key: Note.parse(json.loads(read_text(self.directory / (digest(key) + ".json")))).folder_id
                               for key in self.list_ids()}
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

    def create(self, folder, text, markdown=False):
        rendered = markdown_html(text)[0] if markdown else text_html(text)
        if markdown:
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(rendered, "html.parser")
            for table in soup.find_all("table"):
                table.replace_with("\ufffc")
            plain = "".join(soup.stripped_strings)
        else:
            plain = file_text(text)
        note = Note("created-" + uuid.uuid4().hex, text.splitlines()[0], rendered,
                    plain, str(time.time_ns()), attachments=table_count(rendered), folder_id=folder["id"],
                    folder=tuple(folder["path"]), account=folder["account"])
        atomic_json(self.directory / (digest(note.id) + ".json"), asdict(note))
        return note

    def trash(self, expected):
        if self.read(expected.id) != expected or expected.shared or not expected.default_account:
            raise RuntimeError("削除直前にメモが変更されたか、対応外のアカウントです。")
        (self.directory / (digest(expected.id) + ".json")).unlink()
        return True

    def delete_folder(self, expected):
        folders = self.folders()
        if (not expected["path"] or not expected["default_account"] or expected not in folders or
            any(f["path"][:len(expected["path"])] == expected["path"] and f != expected for f in folders) or
            any(self.read(key).folder_id == expected["id"] for key in self.list_ids())):
            raise RuntimeError("空で変更されていないフォルダだけ削除できます。")
        atomic_json(self.directory / "folders.json", [f for f in folders if f != expected])
        return True


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


def replace_local(path, staging, expected, target):
    """Retain the displaced inode and reject an intervening editor save."""
    write_new(staging, target)
    incoming = staging.stat(follow_symlinks=False)
    swap_file(path, staging)
    sync_directory(path.parent)
    sync_directory(staging.parent)
    if read_text(staging) != expected:
        raise RuntimeError("ファイル交換中に編集されました。displaced.txtに編集内容を保全しました。")
    if read_text(path) != target:
        raise RuntimeError("ファイル更新後に編集されました。同期を停止しました。")
    return [incoming.st_dev, incoming.st_ino]


def move_file(source, destination):
    """Atomic move that refuses to replace an existing destination."""
    libc = ctypes.CDLL(None, use_errno=True)
    function, directory, flag = (libc.renameatx_np, -2, 4) if sys.platform == "darwin" else (libc.renameat2, -100, 1)
    function.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    function.restype = ctypes.c_int
    if function(directory, os.fsencode(source), directory, os.fsencode(destination), flag):
        raise OSError(ctypes.get_errno(), "移動先が存在するか、ファイルを移動できません。")
    sync_directory(source.parent)
    if source.parent != destination.parent:
        sync_directory(destination.parent)


def read_text(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_BYTES:
            raise ValueError("通常のテキストファイルではないか、容量上限を超えています。")
        value = stream.read(MAX_BYTES + 1)
        if len(value) > MAX_BYTES:
            raise ValueError("読取中に容量上限を超えました。")
        return value.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")


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


def classify(base, local, remote, base_local=None, markdown=False, image_text=False):
    if remote is None:
        return "remote_missing"
    if remote.id != base.id:
        raise ValueError("異なるメモの比較はできません。")
    if local is None:
        return "local_missing"
    local = image_plain(local) if image_text else file_text(local)
    remote_text = image_plain(remote.text) if image_text else markdown_text(remote) if markdown else file_text(remote.text)
    base_text = file_text(base_local) if base_local is not None else (
        markdown_text(base) if markdown else file_text(base.text))
    if image_text:
        base_text = image_plain(base_text)
    if local == remote_text:
        if remote.fingerprint == base.fingerprint:
            return "in_sync"
        return "format_changed" if remote_text == base_text else "converged"
    local_changed = local != base_text
    remote_changed = remote_text != image_plain(base.text) if image_text else remote.fingerprint != base.fingerprint
    if local_changed and remote_changed:
        return "conflict"
    if local_changed:
        return "push_pending"
    if remote_changed:
        return "pull_pending"
    return "in_sync"


def folder_ready(state, name):
    return not (any(not r.get("deleted") and Path(r["file"]).is_relative_to(name)
                    for r in state["notes"].values()) or
                any(n != name and Path(n).is_relative_to(name) for n in state.get("folders", {})))


class Workspace:
    def __init__(self, root, source):
        self.root = Path(root).expanduser().resolve()
        self.meta = self.root / ".memo-sync"
        self.source = source
        self.observed = {}
        self.base_cache = {}
        self.local_errors = None

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
                raise DeferredSync("別のmemo-syncが処理中です。") from exc
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
        if any(type(state.get(key, False)) is not bool for key in ("delete_enabled", "markdown_enabled")):
            raise ValueError("同期設定の形式が不正です。")
        if any(key in state and not isinstance(state[key], dict) for key in
               ("folders", "creates", "folder_identity", "folder_pending")):
            raise ValueError("ディレクトリの管理状態が不正です。")
        for note_id, record in state["notes"].items():
            if (not isinstance(note_id, str) or not note_id or not isinstance(record, dict) or
                not isinstance(record.get("base"), str) or
                type(record.get("sync_enabled", False)) is not bool or
                type(record.get("pull_enabled", False)) is not bool):
                raise ValueError("登録の管理状態が不正です。")
            if any(type(record.get(key, False)) is not bool for key in ("markdown", "literal", "image_text", "deleted", "delete_armed")):
                raise ValueError("メモの同期設定が不正です。")
            deletion = record.get("pending_delete")
            if deletion is not None and (
                not isinstance(deletion, dict) or not isinstance(deletion.get("error"), str) or
                not isinstance(deletion.get("operation"), str) or
                not re.fullmatch(r"[0-9a-f]{32}", deletion["operation"])
            ):
                raise ValueError("削除処理の管理状態が不正です。")
            movement = record.get("pending_move")
            if movement is not None and (not isinstance(movement, dict) or
                not isinstance(movement.get("error"), str) or
                not re.fullmatch(r"[0-9a-f]{32}", movement.get("operation", ""))):
                raise ValueError("移動処理の管理状態が不正です。")
            if movement:
                self.note_path(movement.get("target"))
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
        for name, identity in state.get("folder_identity", {}).items():
            self.note_path(name)
            if not isinstance(identity, list) or len(identity) != 2 or any(type(n) is not int for n in identity):
                raise ValueError("フォルダ識別子が不正です。")
        for name, operation in state.get("folder_pending", {}).items():
            self.note_path(name)
            if not isinstance(operation, str) or not re.fullmatch(r"[0-9a-f]{32}", operation):
                raise ValueError("フォルダ削除の記録が不正です。")
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
        if name and folder["default_account"] and state.get("delete_enabled"):
            info = path.stat()
            state.setdefault("folder_identity", {})[name] = [info.st_dev, info.st_ino]
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
        if path.parent.is_symlink() or path.is_symlink():
            raise ValueError("原本保存先へのシンボリックリンクは使用できません。")
        info = path.stat()
        signature = (record["base"], info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)
        cached = self.base_cache.get(relative.parts[1])
        if cached and cached[0] == signature:
            return cached[1]
        note = Note.parse(json.loads(read_text(path)))
        if relative.parts[1] != digest(note.id) or path.stem != note.fingerprint:
            raise ValueError("原本への参照とメモが一致しません。")
        self.base_cache[relative.parts[1]] = (signature, note)
        return note

    def local_base(self, record):
        value = record.get("base_local")
        if value is None:
            return None
        if not isinstance(value, str) or not re.fullmatch(r"[0-9a-f]{64}", value):
            raise ValueError("ローカル基準版の参照が不正です。")
        text = read_text(self.meta / "local-history" / (value + ".txt"))
        if digest(text) != value:
            raise ValueError("ローカル基準版が一致しません。")
        return text

    def save_local(self, text):
        value = digest(text)
        path = self.meta / "local-history" / (value + ".txt")
        if path.exists():
            if read_text(path) != text:
                raise ValueError("ローカル履歴が一致しません。")
        else:
            write_new(path, text)
        return value

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
        initial = file_text(note.text)
        use_markdown = False
        if state.get("markdown_enabled"):
            try:
                initial = markdown_text(note)
                use_markdown = True
            except ValueError:
                pass
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
            if any(record["file"] == filename and not record.get("deleted") for record in state["notes"].values()):
                continue  # A missing file still belongs to its original note.
            try:
                write_new(path, initial)
                break
            except FileExistsError:
                continue
        else:
            raise ValueError("既存ファイルと衝突しない名前を選べませんでした。")
        state["notes"][note.id] = {"file": filename, "base": base, "folder_id": note.folder_id,
                                  "remote_directory": directory.relative_to(self.root).as_posix()}
        if use_markdown:
            state["notes"][note.id].update(markdown=True, base_local=self.save_local(initial))
        atomic_json(self.meta / "state.json", state)
        return path

    def import_all(self, enable=False, note_ids=None):
        with self.lock():
            state = self.state()
            if not enable and not state.get("discover"):
                return {}
            ids = self.source.list_ids() if note_ids is None else note_ids
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

    def discover_local(self, stable=False, refresh=True, filenames=None):
        """Reconcile known locations and add files without duplicating an ambiguous move."""
        with self.lock():
            state = self.state()
            errors = {}
            retryable = []
            try:
                catalog = self.source.folders() if refresh or not state.get("folders") else list(state["folders"].values())
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
                raise DeferredSync(str(error)) from error
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
            if refresh:
                for note_id, record in state["notes"].items():
                    location = getattr(self.source, "note_locations", {}).get(note_id)
                    if (location and record.get("folder_id") and location != record["folder_id"] and
                        record.get("pull_enabled") and not record.get("deleted") and not record.get("pending_move")):
                        try:
                            remote = self.source.read(note_id)
                            if remote:
                                self.pull_move(state, record, remote)
                        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                            errors[record["file"]] = str(error)
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
                        if not isinstance(error, ValueError):
                            retryable.append(str(error))
                if name in errors or name not in folders:
                    continue
                files.extend(Path(parent) / name for name in names if is_note_file(name))
            atomic_json(self.meta / "state.json", state)
            mapped = {record["file"] for record in state["notes"].values() if not record.get("deleted")}
            mapped.update(r["pending_move"]["target"] for r in state["notes"].values() if r.get("pending_move"))
            missing = [record for record in state["notes"].values()
                       if not record.get("deleted") and not self.note_path(record["file"]).exists()]
            pending = state.setdefault("creates", {})
            for path in files:
                filename = path.relative_to(self.root).as_posix()
                if filenames is not None and filename not in filenames:
                    continue
                if filename in mapped or filename in pending:
                    continue
                try:
                    self.note_path(filename)
                    if any(self.note_path(name).exists() and os.path.samefile(path, self.note_path(name))
                           for name in mapped):
                        continue  # Case-only aliases and hard links are not a new note.
                    text = read_text(path)
                    identity = path.stat(follow_symlinks=False)
                    if any(r.get("file_identity") == [identity.st_dev, identity.st_ino] and not r.get("deleted")
                           for r in state["notes"].values()):
                        continue  # An existing note's inode is handled only by the move operation.
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
                    use_markdown = state.get("markdown_enabled", False)
                    original = text
                    literal = False
                    if use_markdown:
                        try:
                            markdown_html(text)
                        except ValueError:
                            literal, use_markdown = True, False
                    if not text.partition("\n")[0].strip() or text.partition("\n")[0] == path.stem:
                        text = retitle(text, path.stem, use_markdown)
                        if text != original:
                            self.save_local(original)
                            signature = digest(text)
                    if not use_markdown:
                        text_html(text)
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
                    try:
                        before_create = read_text(path)
                    except FileNotFoundError:
                        before_create = None
                    if before_create != original:
                        pending.pop(filename)
                        atomic_json(self.meta / "state.json", state)
                        continue
                    if text != original:
                        replace_local(path, self.meta / "local-history" / (operation + "-displaced.txt"), original, text)
                    identity = path.stat(follow_symlinks=False)
                    if not stat.S_ISREG(identity.st_mode):
                        raise ValueError("作成元のファイルが入れ替わったため停止しました。")
                    note = self.source.create(folder, text, markdown=True) if use_markdown else self.source.create(folder, text)
                    matches = note and (markdown_matches(note, text) if use_markdown
                                        else file_text(note.text) == file_text(text))
                    if (not matches or
                        note.folder_id != folder["id"] or note.account != folder["account"]):
                        raise RuntimeError("作成結果の本文またはフォルダが一致しません。再作成を停止しました。")
                    if note.id in state["notes"]:
                        raise RuntimeError("作成結果が既存メモを指しています。")
                    state["notes"][note.id] = {"file": filename, "base": self.snapshot(note),
                                              "folder_id": note.folder_id,
                                              "remote_directory": self.folder_name(folder) or ".",
                                              "sync_enabled": True, "pull_enabled": True,
                                              "delete_armed": state.get("delete_enabled", False),
                                              "file_identity": [identity.st_dev, identity.st_ino],
                                              "last_local": signature}
                    if use_markdown:
                        verify_markdown(note, text)
                        state["notes"][note.id].update(markdown=True, base_local=self.save_local(text))
                    elif literal:
                        state["notes"][note.id]["literal"] = True
                    pending.pop(filename)
                    mapped.add(filename)
                    atomic_json(self.meta / "state.json", state)
                except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                    errors[filename] = str(error)
                    if filename in pending:
                        pending[filename]["error"] = str(error)
                        atomic_json(self.meta / "state.json", state)
                    elif not isinstance(error, ValueError):
                        retryable.append(str(error))
            error_path = self.meta / "directory-errors.json"
            if filenames is not None and error_path.exists():
                previous = json.loads(read_text(error_path))
                present = {path.relative_to(self.root).as_posix() for path in files}
                errors = {**{name: error for name, error in previous.items()
                             if name in present and name not in filenames}, **errors}
            atomic_json(error_path, errors)
            if retryable:
                raise DeferredSync(retryable[0])
            return errors

    def local_work(self):
        """Find saves using local data only; Notes calls must not delay this scan."""
        with self.lock():
            if not (self.meta / "state.json").exists():
                for parent, directories, files in os.walk(self.root, followlinks=False):
                    directories[:] = [n for n in directories if not n.startswith(".") and not (Path(parent)/n).is_symlink()]
                    if any(is_note_file(n) for n in files):
                        raise MissingStateError("state.jsonがない既存フォルダです。重複作成を防ぐため停止しました。管理状態を復旧してください。")
                atomic_json(self.meta / "state.json", self.state())
            state = self.state()
            work = {}
            errors = {}
            mapped = {record["file"] for record in state["notes"].values() if not record.get("deleted")}
            mapped.update(r["pending_move"]["target"] for r in state["notes"].values() if r.get("pending_move"))
            visible = {}
            by_identity = {}
            directories_seen = {}
            for parent, directories, names in os.walk(self.root, followlinks=False):
                directories[:] = [name for name in directories if not name.startswith(".") and
                                   not (Path(parent) / name).is_symlink()]
                info = Path(parent).stat()
                directories_seen[Path(parent).relative_to(self.root).as_posix()] = [info.st_dev, info.st_ino]
                for name in names:
                    if is_note_file(name):
                        filename = (Path(parent) / name).relative_to(self.root).as_posix()
                        try:
                            path = self.note_path(filename)
                            info = path.stat()
                            visible[filename] = (info.st_dev, info.st_ino)
                            by_identity.setdefault((info.st_dev, info.st_ino), []).append(filename)
                        except (OSError, ValueError) as error:
                            errors[filename] = str(error)
            changed = False
            identities = state.setdefault("folder_identity", {})
            if state.get("delete_enabled"):
                for name, folder in state.get("folders", {}).items():
                    if name and folder["default_account"] and name in directories_seen:
                        if identities.get(name) != directories_seen[name]:
                            identities[name] = directories_seen[name]
                            changed = True
            missing_folders = {name for name in identities if name not in directories_seen and
                               identities[name] not in directories_seen.values() and
                               not self.note_path(name).exists()}
            for record in state["notes"].values():
                if record.get("deleted") or record.get("pending_move") or not (record.get("sync_enabled") or record.get("pull_enabled")):
                    continue
                try:
                    path = self.note_path(record["file"])
                    candidates = by_identity.get(tuple(record.get("file_identity", [])), [])
                    if (record["file"] not in visible and len(candidates) == 1 and candidates[0] not in mapped and
                        not candidates[0].startswith("_accounts/") and path.parent.is_dir() and not record.get("pending")):
                        work["move:" + record["file"]] = candidates[0]
                        continue
                    text = read_text(path)
                except FileNotFoundError:
                    if record["file"] in visible:
                        continue  # The file moved after this inventory; classify it on the next scan.
                    path = self.note_path(record["file"])
                    if (state.get("delete_enabled") and record.get("delete_armed") and
                        not record.get("pending") and not record.get("pending_delete") and (path.parent.is_dir() or
                            path.parent.relative_to(self.root).as_posix() in missing_folders) and
                        not any(list(identity) == record.get("file_identity")
                                for name, identity in visible.items() if name != record["file"])):
                        work["delete:" + record["file"]] = record["base"]
                    continue
                except (OSError, ValueError) as error:
                    errors[record["file"]] = str(error)
                    continue
                identity = list(visible.get(record["file"], ()))
                if record.get("file_identity") != identity:
                    record["file_identity"] = identity
                    changed = True
                if state.get("delete_enabled"):
                    identity = list(visible.get(record["file"], ()))
                    local_hash = digest(text)
                    if record.get("file_identity") != identity or record.get("last_local") != local_hash:
                        backup = self.meta / "local-history" / (local_hash + ".txt")
                        if not backup.exists():
                            write_new(backup, text)
                        elif read_text(backup) != text:
                            raise ValueError("削除前のローカル履歴が一致しません。")
                        record.update(file_identity=identity, last_local=local_hash, delete_armed=True)
                        changed = True
                base_text = self.local_base(record)
                if base_text is None:
                    base_text = file_text(self.base(record).text)
                if record.get("image_text"):
                    base_text = image_plain(base_text)
                    text = image_plain(text)
                if (record.get("sync_enabled") and not record.get("pending") and
                    file_text(text) != file_text(base_text)):
                    work[record["file"]] = digest(text)
            for relative in directories_seen:
                if "_accounts" in Path(relative).parts:
                    continue
                relative = "" if relative == "." else unicodedata.normalize("NFC", relative)
                if relative not in state.get("folders", {}):
                    work["directory:" + relative] = relative
            moving = {target for name, target in work.items() if name.startswith("move:")}
            for filename in visible:
                if ("_accounts" in Path(filename).parts[:-1] or filename in mapped or
                    filename in state.get("creates", {}) or filename in moving):
                    continue
                try:
                    path = self.note_path(filename)
                    text = read_text(path)
                except (OSError, ValueError) as error:
                    errors[filename] = str(error)
                    continue
                if text.strip():
                    signature = digest(text)
                    work["create:" + filename] = signature
                    # A copied/moved file must not turn its old path into a destructive deletion.
                    for record in state["notes"].values():
                        key = "delete:" + record["file"]
                        if key in work and (signature == record.get("last_local") or
                                            Path(record["file"]).name == path.name):
                            work.pop(key)
            if changed:
                atomic_json(self.meta / "state.json", state)
            if errors != self.local_errors or not (self.meta / "local-errors.json").exists():
                atomic_json(self.meta / "local-errors.json", errors)
                self.local_errors = errors
            if state.get("delete_enabled"):
                for name in sorted(missing_folders, key=lambda n: len(Path(n).parts), reverse=True):
                    if name not in state.get("folders", {}) or name in state.get("folder_pending", {}):
                        continue
                    work["delete-folder:" + name] = state["folders"][name]["id"]
            return work, state

    def deletions(self, enabled):
        with self.lock():
            state = self.state()
            state["delete_enabled"] = enabled
            if not enabled:
                state.pop("folder_identity", None)
            for record in state["notes"].values():
                path = self.note_path(record["file"])
                record["delete_armed"] = enabled and path.is_file() and not record.get("deleted", False)
            atomic_json(self.meta / "state.json", state)

    def markdown(self, enabled):
        with self.lock():
            state = self.state()
            state["markdown_enabled"] = enabled
            atomic_json(self.meta / "state.json", state)
            if not enabled:
                return {}
            skipped = {}
            for note_id, record in state["notes"].items():
                if record.get("markdown") or record.get("literal") or record.get("deleted") or record.get("pending"):
                    continue
                try:
                    path = self.note_path(record["file"])
                    local = read_text(path)
                    base = self.base(record)
                    if file_text(local) != file_text(base.text):
                        raise ValueError("ローカルに未同期の編集があるため変換を保留しました。")
                    remote = self.source.read(note_id)
                    if not remote or remote.fingerprint != base.fingerprint:
                        raise ValueError("メモ側に未同期の変更があるため変換を保留しました。")
                    markdown_text(remote)
                    record["markdown"] = True
                    record.pop("image_text", None)
                    self.sync_note(state, record, path, local, remote, "pull_pending")
                    # Previously pull-only notes become writable only after a verified conversion.
                    if record.get("pull_enabled"):
                        record["sync_enabled"] = True
                        record.pop("write_blocked", None)
                    atomic_json(self.meta / "state.json", state)
                except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                    skipped[record["file"]] = str(error)
                    if not record.get("pending"):
                        record.pop("markdown", None)
            atomic_json(self.meta / "markdown-skipped.json", skipped)
            return skipped

    def begin_move(self, state, record, remote, local, target, direction):
        if any(record.get(key) for key in ("pending", "pending_delete", "pending_move")):
            raise RuntimeError("未完了の同期があるため移動を停止しました。")
        operation = uuid.uuid4().hex
        atomic_json(self.meta / "operations" / (operation + ".json"), {
            "type": direction, "note_id": remote.id, "from": record["file"], "to": target,
            "remote_backup": self.snapshot(remote), "local_backup": self.save_local(local)})
        record["pending_move"] = {"operation": operation, "target": target,
                                  "error": "移動処理の途中です。結果を確認してください。"}
        atomic_json(self.meta / "state.json", state)

    def finish_move(self, state, record, remote, target):
        record.update(file=target, folder_id=remote.folder_id,
                      remote_directory=self.folder_name({"path": list(remote.folder), "account": remote.account,
                                                        "default_account": remote.default_account}) or ".")
        path = self.note_path(target)
        if path.exists():
            info = path.stat()
            record.update(file_identity=[info.st_dev, info.st_ino], last_local=self.save_local(read_text(path)))
        record.pop("pending_move")
        atomic_json(self.meta / "state.json", state)
        self.file_error(target, None)

    def file_error(self, filename, error):
        path = self.meta / "directory-errors.json"
        errors = json.loads(read_text(path)) if path.exists() else {}
        if error is None:
            errors.pop(filename, None)
        else:
            errors[filename] = error
        atomic_json(path, errors)

    def move_local(self, filename, target, identified=False):
        with self.lock():
            state = self.state()
            filename, target = self.filename(filename), self.filename(target)
            note_id, record = next(((k, r) for k, r in state["notes"].items()
                                    if r["file"] == filename and not r.get("deleted")), (None, None))
            if record is None:
                return
            if record.get("deleted") or not (record.get("sync_enabled") or record.get("pull_enabled")):
                return
            old, path = self.note_path(filename), self.note_path(target)
            alias = (old.parent == path.parent and old.exists() and path.exists() and
                     os.path.samefile(old, path) and old.name not in os.listdir(old.parent))
            if (old.exists() and not alias) or not old.parent.is_dir() or target.startswith("_accounts/"):
                raise ValueError("フォルダ自体の移動・別アカウントへの移動は停止しています。")
            info = path.stat()
            if not identified and [info.st_dev, info.st_ino] != record.get("file_identity"):
                raise ValueError("移動したファイルを一意に確認できません。")
            if any(r is not record and not r.get("deleted") and
                   (r["file"] == target or r.get("pending_move", {}).get("target") == target)
                   for r in state["notes"].values()):
                raise ValueError("移動先は別のメモに登録されています。")
            try:
                local = read_text(path)
                renamed = old.name != path.name
                if renamed and not record.get("sync_enabled"):
                    raise ValueError("本文が読み取り専用のメモは、タイトル行の変更を同期できません。")
                remote = self.source.read(note_id)
                if (not remote or not remote.default_account or remote.folder_id != record.get("folder_id") or
                    (self.folder_name({"path": list(remote.folder), "account": remote.account,
                                       "default_account": remote.default_account}) or ".") != record.get("remote_directory", ".")):
                    raise ValueError("両側で移動されたか、別アカウントのメモです。")
                renamed_text = local
                if renamed:
                    if not local.strip():
                        raise ValueError("本文が空のため、改名による書き戻しを停止しました。")
                    status = classify(self.base(record), local, remote, self.local_base(record),
                                      record.get("markdown", False), record.get("image_text", False))
                    if status in ("conflict", "pull_pending"):
                        raise ValueError("メモ側にも未同期の本文変更があるため、改名を停止しました。")
                    markdown = not record.get("literal") and not record.get("image_text") and (
                        record.get("markdown") or state.get("markdown_enabled"))
                    renamed_text = retitle(local, path.stem, markdown)
                destination = ({"id": remote.folder_id, "path": list(remote.folder), "account": remote.account,
                                "default_account": remote.default_account} if old.parent == path.parent and remote.folder_id else
                               self.source.ensure_folder(path.parent.relative_to(self.root).parts))
                self.remember_folder(state, destination)
            except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                self.file_error(target, str(error))
                if isinstance(error, ValueError):
                    raise
                raise DeferredSync(str(error)) from error
            self.begin_move(state, record, remote, local, target, "push_move")
            if (old.exists() and not alias) or read_text(path) != local:
                raise RuntimeError("移動の反映前にファイルが変わりました。")
            moved = self.source.move(remote, destination) if remote.folder_id != destination["id"] else remote
            if moved.id != note_id or moved.fingerprint != remote.fingerprint or moved.folder_id != destination["id"]:
                raise RuntimeError("移動後のID・本文・移動先が一致しません。")
            if renamed and status in ("converged", "format_changed"):
                record["base"] = self.snapshot(remote)
                if record.get("base_local"):
                    record["base_local"] = self.save_local(local)
            if renamed_text != local:
                staging = self.meta / "local-history" / (record["pending_move"]["operation"] + "-displaced.txt")
                replace_local(path, staging, local, renamed_text)
            self.finish_move(state, record, moved, target)

    def pull_move(self, state, record, remote):
        previous_directory = record.get("remote_directory", ".")
        if previous_directory == ".":
            previous_directory = ""
        previous_account = self.base(record).account or state.get("folders", {}).get(
            previous_directory, {}).get("account")
        if not remote.default_account or previous_account != remote.account:
            raise ValueError("別アカウントへの移動は停止しています。")
        old = self.note_path(record["file"])
        if not old.exists():
            raise ValueError("両側で移動または削除されています。双方を保全して停止しました。")
        folder = {"id": remote.folder_id, "path": list(remote.folder),
                  "account": remote.account, "default_account": remote.default_account}
        directory = self.remember_folder(state, folder)
        path = directory / old.name
        target = path.relative_to(self.root).as_posix()
        self.note_path(target)
        if path == old:
            raise ValueError("同じ場所のフォルダIDが変わったため停止しました。")
        if path.exists() or any(r is not record and r["file"] == target and not r.get("deleted") for r in state["notes"].values()):
            raise ValueError("移動先に同名ファイルがあります。上書きせず停止しました。")
        local = read_text(old)
        self.begin_move(state, record, remote, local, target, "pull_move")
        move_file(old, path)
        self.finish_move(state, record, remote, target)

    def delete_note(self, filename):
        with self.lock():
            state = self.state()
            note_id, record = next(((key, value) for key, value in state["notes"].items()
                                    if value["file"] == filename and not value.get("deleted")), (None, None))
            if record is None:
                return
            path = self.note_path(filename)
            if (not state.get("delete_enabled") or not record.get("delete_armed") or
                not (record.get("sync_enabled") or record.get("pull_enabled")) or
                path.exists() or (not path.parent.is_dir() and
                    path.parent.relative_to(self.root).as_posix() not in state.get("folder_identity", {})) or
                record.get("deleted")):
                return
            if record.get("pending") or record.get("pending_delete") or record.get("pending_move"):
                return
            if not path.parent.is_dir() and not self.folder_missing(state, path.parent.relative_to(self.root).as_posix()):
                return
            base = self.base(record)
            remote = self.source.read(note_id)
            if remote:
                self.snapshot(remote)
                if (remote.fingerprint != base.fingerprint or remote.shared or
                    not remote.default_account):
                    raise RuntimeError("標準メモ側の変更・共有・アカウントを確認してから削除してください。")
            operation = uuid.uuid4().hex
            record["pending_delete"] = {"operation": operation,
                                        "error": "削除処理の途中です。結果を確認してください。"}
            atomic_json(self.meta / "operations" / (operation + ".json"),
                        {"type": "delete", "file": filename, "note_id": note_id,
                         "remote_backup": self.snapshot(remote or base),
                         "local_backup": record.get("last_local")})
            atomic_json(self.meta / "state.json", state)
            try:
                if path.exists():
                    record.pop("pending_delete")
                    atomic_json(self.meta / "state.json", state)
                    return
                if remote:
                    self.source.trash(remote)
                record["deleted"] = True
                record.pop("pending_delete")
                atomic_json(self.meta / "state.json", state)
            except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
                record["pending_delete"]["error"] = str(error)
                atomic_json(self.meta / "state.json", state)
                raise

    def folder_missing(self, state, name):
        identity = state.get("folder_identity", {}).get(name)
        if not identity or self.note_path(name).exists():
            return False
        for parent, directories, _ in os.walk(self.root, followlinks=False):
            directories[:] = [n for n in directories if not n.startswith(".") and
                               not (Path(parent) / n).is_symlink()]
            info = Path(parent).stat()
            if [info.st_dev, info.st_ino] == identity:
                return False
        return True

    def delete_folder(self, name):
        with self.lock():
            state = self.state()
            path = self.note_path(name)
            expected = state.get("folders", {}).get(name)
            if (not state.get("delete_enabled") or not expected or not expected["path"] or
                not self.folder_missing(state, name) or
                name in state.get("folder_pending", {})):
                return
            if not folder_ready(state, name):
                raise RuntimeError("中のメモの削除が完了していません。")
            operation = uuid.uuid4().hex
            atomic_json(self.meta / "operations" / (operation + ".json"),
                        {"type": "delete_folder", "folder": expected})
            state.setdefault("folder_pending", {})[name] = operation
            atomic_json(self.meta / "state.json", state)
            # Native deletion refuses nonempty, shared, moved, and default folders.
            if not self.folder_missing(state, name):
                state["folder_pending"].pop(name)
                atomic_json(self.meta / "state.json", state)
                return
            self.source.delete_folder(expected)
            state["folder_pending"].pop(name)
            state["folders"].pop(name)
            state["folder_identity"].pop(name)
            atomic_json(self.meta / "state.json", state)

    def try_enroll(self, state, note, path):
        try:
            self.enroll(state, note, path)
        except ValueError as error:
            print("memo-sync: 登録済み。自動同期は停止: " + str(error), file=sys.stderr)

    def enroll(self, state, note, path):
        record = state["notes"][note.id]
        if record.get("pending_move"):
            raise ValueError("未完了の移動があります。移動先と操作記録を確認してください。")
        use_markdown = record.get("markdown", False)
        image_text = bool(note.attachments) and not (use_markdown and table_count(note.html) == note.attachments)
        if image_text:
            validate_images(note)
            if use_markdown:
                raise ValueError("Markdown同期中に画像が追加されたため、形式の確認が必要です。")
        projected = image_plain(note.text) if image_text else markdown_text(note) if use_markdown else file_text(note.text)
        if not use_markdown and not image_text:
            text_style(note)
        remote_directory = self.folder_name({"path": list(note.folder), "account": note.account,
                                             "default_account": note.default_account})
        if record.get("remote_directory", ".") != (remote_directory or "."):
            raise ValueError("フォルダの移動を検知しました。同期の再開には確認が必要です。")
        local = read_text(path)
        status = classify(self.base(record), local, note, self.local_base(record), use_markdown, image_text)
        if status == "conflict" or (record.get("pending") and file_text(local) != projected):
            raise ValueError("両側の変更を確認し、本文を一致させてから有効化してください。")
        if file_text(local) == projected:
            record["base"] = self.snapshot(note)
            record.pop("pending", None)
            if use_markdown:
                record["base_local"] = self.save_local(local)
        record["sync_enabled"] = True
        record["pull_enabled"] = True
        record["image_text"] = image_text
        info = path.stat()
        record["file_identity"] = [info.st_dev, info.st_ino]
        record.pop("write_blocked", None)
        atomic_json(self.meta / "state.json", state)

    def enable(self, filename, enabled=True):
        with self.lock():
            state = self.state()
            for note_id, record in state["notes"].items():
                if record["file"] == self.filename(filename) and not record.get("deleted"):
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
        image_text = record.get("image_text", False)
        literal = record.get("literal", False)
        use_markdown = not image_text and not literal and (record.get("markdown", False) or (
            state.get("markdown_enabled", False) and status == "push_pending"))
        if use_markdown and status == "push_pending":
            markdown_text(remote)
            try:
                markdown_html(local)
            except ValueError:
                text_html(local)
                literal, use_markdown = True, False
        target = (image_plain(local) if image_text else file_text(local)) if status == "push_pending" else (
            image_plain(remote.text) if image_text else markdown_text(remote) if use_markdown else file_text(remote.text))
        if status == "push_pending":
            if image_text:
                validate_images(remote)
            elif literal:
                (markdown_text(remote) if table_count(remote.html) else literal_text(remote))
                text_html(local)
            elif use_markdown:
                markdown_text(remote)
                markdown_html(local)
            else:
                render_text(remote, local)
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
            "markdown": use_markdown,
            "literal": literal,
            "image_text": image_text,
        }
        atomic_json(self.meta / "operations" / (operation + ".json"), {
            **record["pending"], "file": record["file"], "note_id": remote.id,
            "local_backup": str(local_backup.relative_to(self.meta)),
            "remote_backup": self.snapshot(remote),
        })
        # A durable marker makes a timeout/crash fail closed on the next run.
        atomic_json(self.meta / "state.json", state)
        try:
            before_write = read_text(path)
        except FileNotFoundError:
            before_write = None
        if before_write != local:
            record.pop("pending")
            atomic_json(self.meta / "state.json", state)
            raise DeferredSync("保存内容が更新されたため、最新の版を待っています。")
        if status == "push_pending":
            try:
                updated = (self.source.replace_images(remote, local) if image_text else
                           self.source.replace(remote, local, literal=True) if literal else
                           self.source.replace(remote, local, markdown=True) if use_markdown else self.source.replace(remote, local))
            except DeferredSync:
                # DeferredSync is allowed only before any content mutation.
                record.pop("pending")
                atomic_json(self.meta / "state.json", state)
                raise
            # The image adapter additionally checks exact text except native image-boundary line breaks.
            matches = updated and (content_key(image_plain(updated.text)) == content_key(target) if image_text else
                                   markdown_matches(updated, local) if use_markdown else
                                   file_text(updated.text) == target)
            if updated is None or updated.id != remote.id or not matches:
                raise RuntimeError("書き戻した本文が一致しません。原本を保全して同期を停止しました。")
            if use_markdown:
                verify_markdown(updated, local)
            self.snapshot(updated)
            try:
                after_write = read_text(path)
            except FileNotFoundError:
                after_write = None
            # The verified Notes write is complete even if the user has now deleted the file.
            if after_write is not None and after_write != local:
                self.save_local(after_write)
        else:
            updated = self.source.read(remote.id)
            if updated != remote:
                raise RuntimeError("同期直前にメモが更新されました。同期を停止しました。")
            staging = self.meta / "local-history" / (operation + "-displaced.txt")
            record["file_identity"] = replace_local(path, staging, local, target)
        record["base"] = self.snapshot(updated)
        if literal:
            record.update(literal=True, markdown=False, base_local=self.save_local(local if status == "push_pending" else target))
        if use_markdown or image_text:
            if use_markdown:
                record["markdown"] = True
            record["base_local"] = self.save_local(local if status == "push_pending" else target)
        record.pop("pending")
        atomic_json(self.meta / "state.json", state)
        return updated

    def inspect(self, filename=None, sync=False, stable=False, pull_only=False):
        results = []
        with self.lock():
            state = self.state()
            active_names = {r["file"] for r in state["notes"].values() if not r.get("deleted")}
            for note_id, record in state["notes"].items():
                if filename and record["file"] != self.filename(filename):
                    continue
                if record.get("deleted") and record["file"] in active_names:
                    continue
                baseline = record["base"]
                base = self.base(record)
                if base.id != note_id:
                    raise ValueError("原本のメモIDが一致しません。")
                path = self.note_path(record["file"])
                if record.get("deleted") or record.get("pending_delete") or record.get("pending_move"):
                    results.append({"file": record["file"], "status": "deleted" if record.get("deleted") else "move_interrupted" if record.get("pending_move") else "delete_interrupted",
                                    "note_id": note_id, "writes_enabled": False, "pull_enabled": False,
                                    "error": (record.get("pending_move") or record.get("pending_delete", {})).get("error"),
                                    "local_diff": [], "remote_diff": []})
                    continue
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
                except (OSError, ValueError) as exc:
                    local = None
                    read_error = str(exc)
                if remote:
                    self.snapshot(remote)
                if (sync and remote and record.get("pull_enabled") and record.get("folder_id") and
                    remote.folder_id != record["folder_id"]):
                    try:
                        self.pull_move(state, record, remote)
                        path = self.note_path(record["file"])
                        local = read_text(path)
                    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
                        read_error = str(exc)
                try:
                    if remote and record.get("literal"):
                        literal_text(remote)
                    status = "unavailable" if read_error else classify(
                        base, local, remote, self.local_base(record), record.get("markdown", False), record.get("image_text", False))
                except ValueError as exc:
                    status = "unsupported"
                    read_error = str(exc)
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
                    if (sync and not pending.get("error") and not pending.get("image_text") and displaced_ok and remote and local is not None and
                        digest(file_text(local)) == pending["target"] and
                        (markdown_matches(remote, local) if pending.get("markdown")
                         else file_text(local) == file_text(remote.text))):
                        record["base"] = self.snapshot(remote)
                        if pending.get("markdown"):
                            record.update(markdown=True, base_local=self.save_local(local))
                        if pending.get("literal"):
                            record.update(literal=True, markdown=False, base_local=self.save_local(local))
                        record.pop("pending")
                        atomic_json(self.meta / "state.json", state)
                        status = "in_sync"
                    else:
                        status = "interrupted"
                        error = pending.get("error", "中断された同期があります。原本・ファイル履歴を確認してください。")
                elif (sync and (enabled or pull_enabled) and remote and local is not None and
                      (not stable or settled)):
                    try:
                        if status == "pull_pending" or (status == "push_pending" and enabled and not pull_only):
                            remote = self.sync_note(state, record, path, local, remote, status)
                            status = "in_sync"
                        elif status in ("converged", "format_changed"):
                            record["base"] = self.snapshot(remote)
                            atomic_json(self.meta / "state.json", state)
                            status = "in_sync"
                    except DeferredSync as exc:
                        status, error = "waiting", str(exc)
                    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
                        error = str(exc)
                        if record.get("pending"):
                            record["pending"]["error"] = error
                            atomic_json(self.meta / "state.json", state)
                        status = "interrupted" if record.get("pending") else "unsupported"
                if record["base"] != baseline:
                    base = self.base(record)
                    try:
                        local = read_text(path)
                        if status == "in_sync":
                            status = classify(base, local, remote, self.local_base(record),
                                              record.get("markdown", False), record.get("image_text", False))
                    except FileNotFoundError:
                        local = None
                        status = "local_missing"
                current = remote or base
                diff_base = self.local_base(record)
                if diff_base is None:
                    diff_base = file_text(base.text)
                try:
                    diff_remote = markdown_text(current) if record.get("markdown") else file_text(current.text)
                except ValueError:
                    diff_remote = file_text(current.text)
                result = {
                    "file": record["file"], "status": status,
                    "local_hash": digest(local) if local is not None else None, "baseline": record["base"],
                    "note_id": note_id, "writes_enabled": enabled, "error": error,
                    "modified": remote.modified if remote else None,
                    "pull_enabled": pull_enabled, "write_blocked": record.get("write_blocked"),
                    "attachments": current.attachments, "shared": current.shared,
                    "local_diff": list(difflib.unified_diff(
                        file_text(diff_base).splitlines(keepends=True),
                        (local or "").splitlines(keepends=True), fromfile="base", tofile="file")),
                    "remote_diff": list(difflib.unified_diff(
                        file_text(diff_base).splitlines(keepends=True),
                        file_text(diff_remote).splitlines(keepends=True), fromfile="base", tofile="Notes")),
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


def watch_workspace(workspace, interval):
    observed, handled, seen, queue, reported = {}, {}, {}, {}, {}
    retry_after = {}
    next_index = next_folders = next_audit = 0
    previous_error = None
    while True:
        selected = None
        try:
            now = time.monotonic()
            work, state = workspace.local_work()
            versions = dict(work)
            for name, target in work.items():
                if name.startswith("move:"):
                    info = workspace.note_path(target).stat(follow_symlinks=False)
                    versions[name] = (target, info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)
            observed = {name: value for name, value in observed.items() if name in work}
            handled = {name: value for name, value in handled.items() if name in work}
            for name, signature in versions.items():
                if name not in observed or observed[name][0] != signature:
                    observed[name] = (signature, now)
                    retry_after.pop(name, None)
            ready = [name for name, signature in work.items()
                     if now - observed[name][1] >= (DELETE_SETTLE_SECONDS if name.startswith(("delete:", "delete-folder:")) else SAVE_SETTLE_SECONDS)
                     and handled.get(name) != versions[name] and now >= retry_after.get(name, 0)
                     and (not name.startswith("delete-folder:") or folder_ready(state, name[len("delete-folder:"):]))]
            results = []
            if ready:
                name = ready[0]
                selected = (name, versions[name])
                if name.startswith("delete:"):
                    workspace.delete_note(name[len("delete:"):])
                elif name.startswith("move:"):
                    workspace.move_local(name[len("move:"):], work[name])
                    results = workspace.inspect(work[name], sync=True)
                elif name.startswith("delete-folder:"):
                    workspace.delete_folder(name[len("delete-folder:"):])
                elif name.startswith(("create:", "directory:")):
                    filenames = {name[len("create:"):]} if name.startswith("create:") else set()
                    workspace.discover_local(refresh=False, filenames=filenames)
                else:
                    results = workspace.inspect(name, sync=True)
                handled[name] = versions[name]
            elif now >= next_index:
                index = workspace.source.index()
                for note_id, record in state["notes"].items():
                    if record.get("deleted"):
                        continue
                    modified = index.get(note_id)
                    if note_id not in seen:
                        seen[note_id] = workspace.base(record).modified
                    if modified != seen[note_id]:
                        token = (modified, record["file"])
                        if note_id not in queue or queue[note_id][0] != token:
                            queue[note_id] = (token, now)
                if state.get("discover"):
                    for note_id in index:
                        if note_id not in state["notes"]:
                            queue.setdefault(note_id, ((index[note_id], None), now))
                # Always leave room to consume results even when an index call takes longer than its interval.
                next_index = time.monotonic() + interval
            elif now >= next_folders:
                workspace.discover_local(refresh=True, filenames=set())
                next_folders = time.monotonic() + 2
            else:
                if now >= next_audit:
                    # ponytail: timestamp granularity needs a fallback scan; one note per turn keeps saves responsive.
                    for note_id, record in state["notes"].items():
                        queue.setdefault(note_id, ((seen.get(note_id), record["file"]), now - 1))
                    next_audit = now + 300
                candidates = [note_id for note_id, ((_, filename), changed) in queue.items()
                              if now - changed >= SAVE_SETTLE_SECONDS and filename not in work]
                # Changed timestamps and new notes precede unchanged fallback audit entries.
                candidates.sort(key=lambda note_id: queue[note_id][0][0] == seen.get(note_id))
                if candidates:
                    note_id = candidates[0]
                    (modified, filename), _ = queue.pop(note_id)
                    if note_id in state["notes"]:
                        filename = state["notes"][note_id]["file"]
                    if filename is None:
                        workspace.import_all(note_ids=[note_id])
                    else:
                        results = workspace.inspect(filename, sync=True, pull_only=True)
                    seen[note_id] = modified if filename is None else (
                        results[0].get("modified") if results else seen.get(note_id))
            for result in results:
                if selected and result["status"] in ("unavailable", "waiting"):
                    handled.pop(selected[0], None)
                    retry_after[selected[0]] = time.monotonic() + 2
                signature = json.dumps(result, ensure_ascii=False, sort_keys=True)
                if reported.get(result["file"]) != signature:
                    print_result(result)
                    reported[result["file"]] = signature
                if result.get("note_id") and result.get("modified"):
                    seen[result["note_id"]] = result["modified"]
            previous_error = None
        except MissingStateError:
            raise
        except DeferredSync as error:
            if selected:
                retry_after[selected[0]] = time.monotonic() + 2
            if str(error) != previous_error:
                print("memo-sync: " + str(error), file=sys.stderr, flush=True)
                previous_error = str(error)
        except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
            if selected:
                handled[selected[0]] = selected[1]
            if str(error) != previous_error:
                print("memo-sync: " + str(error), file=sys.stderr, flush=True)
            previous_error = str(error)
        if selected is None:
            time.sleep(0.2)


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
    deletion = commands.add_parser("deletions", help="ファイルから標準メモへの削除同期を設定")
    deletion.add_argument("mode", choices=("on", "off"))
    md = commands.add_parser("markdown", help="新規・編集済みファイルのMarkdown書式を有効化")
    md.add_argument("mode", choices=("on", "off"))
    for command in ("enable", "disable"):
        enrollment = commands.add_parser(command, help="登録ファイルの自動同期を" + ("有効化" if command == "enable" else "停止"))
        enrollment.add_argument("file")
    status = commands.add_parser("status", help="両側の変更と競合を確認")
    status.add_argument("--json", action="store_true")
    diff = commands.add_parser("diff", help="登録したファイルの両側の差分を表示")
    diff.add_argument("file")
    movement = commands.add_parser("move", help="対応が確定した移動元と移動先を指定してメモを移動")
    movement.add_argument("old")
    movement.add_argument("new")
    sync = commands.add_parser("sync", help="有効化したメモを一度双方向同期")
    sync.add_argument("file", nargs="?")
    sync.add_argument("--json", action="store_true")
    watch = commands.add_parser("watch", help="有効化したメモの双方向同期を継続")
    watch.add_argument("--interval", type=float, default=1, help="メモ側の更新日時を確認する間隔（秒）")
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
        elif args.command == "deletions":
            workspace.deletions(args.mode == "on")
        elif args.command == "markdown":
            skipped = workspace.markdown(args.mode == "on")
            if skipped:
                print(json.dumps({"skipped": skipped}, ensure_ascii=False, indent=2))
        elif args.command == "move":
            workspace.move_local(args.old, args.new, identified=True)
            results = workspace.inspect(args.new, sync=True)
            for result in results:
                print_result(result)
            return int(any(r["status"] not in ("in_sync", "waiting", "push_pending") for r in results))
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
                                                            "folder_changed", "create_interrupted", "delete_interrupted", "move_interrupted") for r in results):
                return 1
            if any(r["status"] == "unavailable" for r in results):
                return 1
        else:
            if not math.isfinite(args.interval) or args.interval < 1:
                raise ValueError("確認間隔は1秒以上にしてください。")
            watch_workspace(workspace, args.interval)
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
