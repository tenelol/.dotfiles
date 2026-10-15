#!/usr/bin/env python3
"""Seed Rift-like controls once, then preserve OmniWM's GUI settings."""

import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import tomllib
import uuid


def field(block, name, value):
    line = f"{name} = {json.dumps(value)}"
    result, count = re.subn(rf"(?m)^[ \t]*{re.escape(name)}[ \t]*=.*$", lambda _: line, block)
    if count > 1:
        raise ValueError(f"ambiguous field: {name}")
    return result if count else block.replace("\n", "\n" + line + "\n", 1)


def configure(text, preset):
    config = tomllib.loads(text)
    if config.get("schemaVersion") != 4:
        raise ValueError("expected OmniWM settings schema 4")
    names = {str(i) for i in range(1, 10)}
    if {w["name"] for w in config["workspaces"]} != names:
        raise ValueError("expected the existing workspaces 1 through 9")
    bindings = dict(preset["hotkeys"])
    for i in range(9):
        bindings[f"switchWorkspace.{i}"] = f"Option+{i + 1}"
        bindings[f"moveToWorkspace.{i}"] = f"Option+Shift+{i + 1}"
    ids = [h["id"] for h in config["hotkeys"]]
    if len(set(ids)) != len(ids) or not bindings.keys() <= set(ids):
        raise ValueError("missing or duplicate OmniWM hotkey actions")

    seen_apps = set()
    blocks = re.split(r"(?m)(?=^\[\[)", text)
    for i, block in enumerate(blocks):
        if block.startswith("[[hotkeys]]"):
            action = tomllib.loads(block)["hotkeys"][0]["id"]
            if action in bindings:
                blocks[i] = field(block, "binding", bindings[action])
        elif block.startswith("[[workspaces]]"):
            workspace = tomllib.loads(block)["workspaces"][0]
            if "displayName" in workspace:
                blocks[i] = field(block, "displayName", workspace["name"])
        elif block.startswith("[[appRules]]"):
            rule = tomllib.loads(block)["appRules"][0]
            app = rule.get("bundleId")
            if app in preset["appWorkspaces"]:
                if app in seen_apps:
                    raise ValueError(f"ambiguous app rules: {app}")
                seen_apps.add(app)
                blocks[i] = field(block, "assignToWorkspace", preset["appWorkspaces"][app])

    result = "".join(blocks)
    result, count = re.subn(r"(?m)^ipcEnabled\s*=\s*(true|false)\s*$", "ipcEnabled = true", result)
    if count != 1:
        raise ValueError("expected one IPC setting")
    for app, workspace in preset["appWorkspaces"].items():
        if app not in seen_apps:
            rule_id = str(uuid.uuid5(uuid.NAMESPACE_URL, "omniwm-rift:" + app)).upper()
            result += ("\n[[appRules]]\n" + f"id = {json.dumps(rule_id)}\n"
                       + f"bundleId = {json.dumps(app)}\nassignToWorkspace = {json.dumps(workspace)}\n")

    applied = tomllib.loads(result)
    chords = set()
    for hotkey in applied["hotkeys"]:
        if hotkey["binding"] == "Unassigned":
            continue
        parts = hotkey["binding"].casefold().split("+")
        chord = (tuple(sorted(parts[:-1])), parts[-1])
        if chord in chords:
            raise ValueError(f"conflicting shortcut: {hotkey['binding']}")
        chords.add(chord)
    return result


def apply(path, preset):
    marker = path.with_name(".rift-preset-applied")
    # shortcut: first launch creates the full schema; apply on the next switch for a fresh Mac.
    if not path.exists() or marker.exists():
        return
    if path.is_symlink():
        raise ValueError("refusing to replace a settings symlink")
    original = path.read_bytes()
    changed = configure(original.decode(), preset).encode()
    if changed == original:
        marker.touch(mode=0o600, exist_ok=False)
        return
    backup = path.with_name(path.name + ".before-rift-" + hashlib.sha256(original).hexdigest()[:12])
    if not backup.exists():
        with os.fdopen(os.open(backup, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "wb") as output:
            output.write(original)
    elif backup.read_bytes() != original:
        raise ValueError("backup does not match the original settings")
    staged = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as output:
            staged = Path(output.name)
            output.write(changed)
            output.flush()
            os.fsync(output.fileno())
        staged.chmod(path.stat().st_mode & 0o777)
        if path.read_bytes() != original:
            raise ValueError("settings changed during preparation; retry")
        os.replace(staged, path)
        marker.touch(mode=0o600, exist_ok=False)
        print(f"OmniWM Rift controls applied; backup: {backup}")
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)


if __name__ == "__main__":
    apply(Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text()))
