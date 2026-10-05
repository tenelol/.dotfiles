#!/usr/bin/env python3
"""Install regular workflow files: Automator cannot read symlink NSFileWrappers."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import sys
import tempfile
import uuid


MARKER = ".memo-sync-managed.json"
FILES = ("Info.plist", "document.wflow")


def signature(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError("サービスの配置先は通常のディレクトリである必要があります。")
    if set(p.name for p in root.iterdir()) != {"Contents"}:
        raise ValueError("サービスに管理対象外のファイルがあります。")
    contents = root / "Contents"
    if contents.is_symlink() or not contents.is_dir():
        raise ValueError("サービスのContentsが不正です。")
    names = set(p.name for p in contents.iterdir())
    if not names:
        return {}
    if names != {*FILES, MARKER}:
        raise ValueError("管理対象外のサービスは上書きしません。")
    result = {}
    for name in (*FILES, MARKER):
        path = contents / name
        if path.is_symlink() or not path.is_file():
            raise ValueError("サービスには通常ファイルのみを配置してください。")
        result[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    marker = json.loads((contents / MARKER).read_bytes())
    if not isinstance(marker, dict) or marker.get("version") != 1 or marker.get("files") != {name: result[name] for name in FILES}:
        raise ValueError("サービスが変更されています。上書きしません。")
    return result


def remove_owned(root, expected):
    # Never recursively remove a bundle whose contents may have been changed.
    if signature(root) != expected:
        raise ValueError("退避したサービスが変更されたため、そのまま残します。")
    for name in (*FILES, MARKER) if expected else ():
        (root / "Contents" / name).unlink()
    (root / "Contents").rmdir()
    root.rmdir()


def install(destination, info, workflow):
    destination = Path(destination).expanduser().absolute()
    if destination.name != "MemoSyncRegister.workflow":
        raise ValueError("配置対象はMemoSyncRegister.workflowに限定されています。")
    payloads = {"Info.plist": Path(info).read_bytes(), "document.wflow": Path(workflow).read_bytes()}
    for data in payloads.values():
        if not isinstance(plistlib.loads(data), dict):
            raise ValueError("サービスのplist形式が不正です。")
    hashes = {name: hashlib.sha256(data).hexdigest() for name, data in payloads.items()}
    existed = destination.exists() or destination.is_symlink()
    previous = signature(destination) if existed else None
    if previous and all(previous[name] == hashes[name] for name in FILES):
        return "unchanged"
    destination.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".memo-sync-stage-", dir=destination.parent))
    contents = stage / "Contents"
    contents.mkdir()
    for name, data in payloads.items():
        (contents / name).write_bytes(data)
    (contents / MARKER).write_text(json.dumps({"version": 1, "files": hashes}))
    stage_signature = signature(stage)
    backup = destination.with_name(".memo-sync-backup-" + uuid.uuid4().hex)
    moved = False
    try:
        if existed:
            if signature(destination) != previous:
                raise ValueError("配置直前にサービスが変更されました。")
            os.rename(destination, backup)
            moved = True
            if signature(backup) != previous:
                raise ValueError("配置中にサービスが変更されました。")
        os.rename(stage, destination)
    except Exception:
        if moved and not destination.exists() and not destination.is_symlink():
            os.rename(backup, destination)
        raise
    finally:
        if stage.exists():
            remove_owned(stage, stage_signature)
    if moved:
        try:
            remove_owned(backup, previous)
        except ValueError as error:
            print(str(error) + " " + str(backup), file=sys.stderr)
    return "installed"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--destination", required=True, type=Path)
    parser.add_argument("--info", required=True, type=Path)
    parser.add_argument("--workflow", required=True, type=Path)
    args = parser.parse_args()
    try:
        print("memo-sync service: " + install(args.destination, args.info, args.workflow))
    except (OSError, ValueError) as error:
        print("memo-sync service: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
