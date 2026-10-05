"""Edit Notes text through Accessibility without replacing image attachments."""

import ctypes as C
from contextlib import contextmanager
import difflib
import subprocess


class DeferredSync(RuntimeError):
    """No content was written; retry after the UI or permission becomes available."""


def text_edits(original, target):
    """Reverse-ordered edits that never include an attachment character."""
    positions = [i for i, c in enumerate(original) if c != "\ufffc"]
    plain = original.replace("\ufffc", "")
    edits = []
    for tag, a, b, c, d in difflib.SequenceMatcher(None, plain, target, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        start = positions[a] if a < len(positions) else len(original)
        if a == b:
            edits.append((start, start, target[c:d]))
            continue
        runs = []
        for position in positions[a:b]:
            if runs and runs[-1][1] == position:
                runs[-1] = (runs[-1][0], position + 1)
            else:
                runs.append((position, position + 1))
        edits.extend((lo, hi, target[c:d] if i == 0 else "") for i, (lo, hi) in enumerate(runs))
    return sorted(edits, key=lambda item: item[0], reverse=True)


class Range(C.Structure):
    _fields_ = [("location", C.c_long), ("length", C.c_long)]


class NotesText:
    def __init__(self):
        self.cf = C.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
        self.ax = C.CDLL("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices")
        pointer, integer = C.c_void_p, C.c_long
        signatures = [
            (self.cf, "CFRelease", None, [pointer]),
            (self.cf, "CFRetain", pointer, [pointer]),
            (self.cf, "CFGetTypeID", C.c_ulong, [pointer]),
            (self.cf, "CFStringGetTypeID", C.c_ulong, []),
            (self.cf, "CFStringCreateWithCString", pointer, [pointer, C.c_char_p, C.c_uint]),
            (self.cf, "CFStringGetLength", integer, [pointer]),
            (self.cf, "CFStringGetCString", C.c_bool, [pointer, C.c_char_p, integer, C.c_uint]),
            (self.cf, "CFArrayGetCount", integer, [pointer]),
            (self.cf, "CFArrayGetValueAtIndex", pointer, [pointer, integer]),
            (self.ax, "AXIsProcessTrusted", C.c_bool, []),
            (self.ax, "AXUIElementCreateApplication", pointer, [C.c_int]),
            (self.ax, "AXUIElementCopyAttributeValue", C.c_int, [pointer, pointer, C.POINTER(pointer)]),
            (self.ax, "AXUIElementSetAttributeValue", C.c_int, [pointer, pointer, pointer]),
            (self.ax, "AXValueCreate", pointer, [C.c_int, pointer]),
        ]
        for library, name, result, args in signatures:
            function = getattr(library, name)
            function.restype, function.argtypes = result, args
        if not self.ax.AXIsProcessTrusted():
            raise DeferredSync("画像付きメモの本文編集には、実行元のアクセシビリティ許可が必要です。")
        pid = subprocess.check_output(["/usr/bin/pgrep", "-x", "Notes"], text=True).split()
        if len(pid) != 1:
            raise DeferredSync("標準メモのウインドウを開くと、画像付きメモの同期を再開します。")
        self.root = self.ax.AXUIElementCreateApplication(int(pid[0]))
        self.body = None

    def close(self):
        if self.body:
            self.cf.CFRelease(self.body)
        self.cf.CFRelease(self.root)

    @contextmanager
    def string(self, value):
        pointer = self.cf.CFStringCreateWithCString(None, value.encode(), 0x08000100)
        try:
            yield pointer
        finally:
            self.cf.CFRelease(pointer)

    @contextmanager
    def attribute(self, element, name):
        value = C.c_void_p()
        with self.string(name) as key:
            self.ax.AXUIElementCopyAttributeValue(element, key, C.byref(value))
        try:
            yield value.value
        finally:
            if value.value:
                self.cf.CFRelease(value)

    def text(self, element, name):
        with self.attribute(element, name) as value:
            if not value or self.cf.CFGetTypeID(value) != self.cf.CFStringGetTypeID():
                return ""
            data = C.create_string_buffer(self.cf.CFStringGetLength(value) * 4 + 1)
            if not self.cf.CFStringGetCString(value, data, len(data), 0x08000100):
                raise RuntimeError("メモ画面の文字列を読み取れません。")
            return data.value.decode()

    def walk(self, element, depth=0):
        yield element
        if depth < 18:
            with self.attribute(element, "AXChildren") as children:
                if children:
                    for i in range(self.cf.CFArrayGetCount(children)):
                        yield from self.walk(self.cf.CFArrayGetValueAtIndex(children, i), depth + 1)

    def set(self, element, name, value):
        with self.string(name) as key:
            if self.ax.AXUIElementSetAttributeValue(element, key, value):
                raise RuntimeError("標準メモの部分編集に失敗しました。")

    def select(self, title, selected):
        needle = "".join(title.split())[:24]
        matches = []
        for element in self.walk(self.root):
            if self.text(element, "AXRole") == "AXRow" and any(
                needle in "".join(self.text(child, "AXValue").split()) for child in self.walk(element)
            ):
                matches.append(self.cf.CFRetain(element))
        try:
            if len(matches) > 20:
                raise DeferredSync("対象メモを一覧から絞り込めないため、書き込みを保留しています。")
            for row in matches:
                self.set(row, "AXSelected", C.c_void_p.in_dll(self.cf, "kCFBooleanTrue").value)
                if selected():
                    break
            else:
                raise DeferredSync("標準メモで対象が一覧に表示されると、画像付きメモの同期を再開します。")
        finally:
            for row in matches:
                self.cf.CFRelease(row)
        bodies = [self.cf.CFRetain(e) for e in self.walk(self.root)
                  if self.text(e, "AXIdentifier") == "Note Body Text View"]
        if len(bodies) != 1:
            for body in bodies:
                self.cf.CFRelease(body)
            raise DeferredSync("標準メモの編集ウインドウを1つにすると同期を再開します。")
        self.body = bodies[0]

    def replace(self, original, target, selected):
        current = self.text(self.body, "AXValue")
        if current.rstrip("\n") != original.rstrip("\n"):
            raise DeferredSync("メモ画面と本文が一致しないため、書き込みを保留しています。")
        for start, end, replacement in text_edits(current, target):
            if not selected() or self.text(self.body, "AXValue") != current:
                raise RuntimeError("部分編集中にメモが切り替わったか、本文が変更されました。")
            span = Range(len(current[:start].encode("utf-16-le")) // 2,
                         len(current[start:end].encode("utf-16-le")) // 2)
            value = self.ax.AXValueCreate(4, C.byref(span))  # kAXValueCFRangeType
            try:
                self.set(self.body, "AXSelectedTextRange", value)
            finally:
                self.cf.CFRelease(value)
            if self.text(self.body, "AXSelectedText") != current[start:end]:
                raise RuntimeError("編集する文字範囲が一致しません。")
            with self.string(replacement) as value:
                self.set(self.body, "AXSelectedText", value)
            current = current[:start] + replacement + current[end:]
        if self.text(self.body, "AXValue") != current or current.replace("\ufffc", "") != target:
            raise RuntimeError("部分編集後の全文が一致しません。")
