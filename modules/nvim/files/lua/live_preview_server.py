#!/usr/bin/env python3

import argparse
import mimetypes
import os
import posixpath
import queue
import threading
import time
import urllib.parse
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

INJECT_SNIPPET = """<script>
(() => {
  const events = new EventSource("/__preview_events");
  events.addEventListener("reload", () => window.location.reload());
  events.onerror = () => {
    events.close();
    setTimeout(() => window.location.reload(), 1000);
  };
})();
</script>"""


class PreviewState:
    def __init__(self, root: Path):
        self.root = root
        self.clients = set()
        self.lock = threading.Lock()
        self.last_mtime = self.scan_mtime()

    def scan_mtime(self) -> float:
        latest = 0.0
        for base, dirs, files in os.walk(self.root):
            dirs[:] = [d for d in dirs if d != ".git"]
            for name in files:
                try:
                    mtime = os.path.getmtime(os.path.join(base, name))
                except FileNotFoundError:
                    continue
                latest = max(latest, mtime)
        return latest

    def watch(self):
        while True:
            time.sleep(0.35)
            current = self.scan_mtime()
            if current > self.last_mtime:
                self.last_mtime = current
                self.broadcast("reload")

    def broadcast(self, event: str):
        with self.lock:
            dead = []
            for client in self.clients:
                try:
                    client.put_nowait(event)
                except Exception:
                    dead.append(client)
            for client in dead:
                self.clients.discard(client)

    def subscribe(self):
        client = queue.Queue()
        with self.lock:
            self.clients.add(client)
        return client

    def unsubscribe(self, client):
        with self.lock:
            self.clients.discard(client)


class PreviewHandler(BaseHTTPRequestHandler):
    server_version = "LivePreview/1.0"
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        if self.path == "/__preview_events":
            self.handle_events()
            return

        path = self.resolve_path()
        if path is None:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return

        if path.is_dir():
            path = path / "index.html"
            if not path.exists():
                self.send_error(HTTPStatus.NOT_FOUND, "File not found")
                return

        if not path.exists():
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return

        if path.suffix.lower() in {".html", ".htm"}:
            self.serve_html(path)
            return

        self.serve_file(path)

    def log_message(self, format, *args):
        return

    def resolve_path(self):
        parsed = urllib.parse.urlparse(self.path)
        relative = urllib.parse.unquote(parsed.path)
        normalized = posixpath.normpath(relative)
        normalized = normalized.lstrip("/")
        candidate = (self.server.root / normalized).resolve()
        try:
            candidate.relative_to(self.server.root)
        except ValueError:
            return None
        return candidate

    def serve_html(self, path: Path):
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            content = path.read_text(encoding="utf-8", errors="replace")

        if "</body>" in content:
            content = content.replace("</body>", INJECT_SNIPPET + "\n</body>", 1)
        else:
            content += "\n" + INJECT_SNIPPET

        data = content.encode("utf-8")
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def serve_file(self, path: Path):
        ctype = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
        try:
            data = path.read_bytes()
        except OSError:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def handle_events(self):
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "keep-alive")
        self.end_headers()

        client = self.server.state.subscribe()
        try:
            self.wfile.write(b": connected\n\n")
            self.wfile.flush()
            while True:
                try:
                    event = client.get(timeout=30)
                    payload = f"event: {event}\ndata: {event}\n\n".encode("utf-8")
                    self.wfile.write(payload)
                    self.wfile.flush()
                except queue.Empty:
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            self.server.state.unsubscribe(client)


class PreviewServer(ThreadingHTTPServer):
    def __init__(self, server_address, handler_class, root: Path):
        super().__init__(server_address, handler_class)
        self.root = root.resolve()
        self.state = PreviewState(self.root)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--port", type=int, default=5500)
    return parser.parse_args()


def main():
    args = parse_args()
    root = Path(args.root).resolve()

    server = PreviewServer(("127.0.0.1", args.port), PreviewHandler, root)
    watcher = threading.Thread(target=server.state.watch, daemon=True)
    watcher.start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
