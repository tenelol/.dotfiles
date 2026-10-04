#!/usr/bin/env python3
"""Keep Zen's selected profile when its installation path changes."""

import argparse
import configparser
import io
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def parser(text):
    result = configparser.RawConfigParser()
    result.optionxform = str
    result.read_string(text)
    return result


def atomic_write(path, data, expected=None):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if expected is not None and path.read_text() != expected:
        raise RuntimeError(f"Zen profile selection changed during activation: {path}")
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        stream.write(data)
        temporary = stream.name
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)


def preserve(home, new_hash, legacy_hash, prefer_previous=False):
    base = home / "Library/Application Support/zen"
    profiles = base / "profiles.ini"
    if not profiles.is_file():
        return None
    original = profiles.read_text()
    database = parser(original)
    state = home / ".local/state/dotfiles/zen-install.json"
    previous = json.loads(state.read_text()).get("hash") if state.is_file() else None
    target = "Install" + new_hash
    migrating = prefer_previous and previous and previous != new_hash
    if database.has_option(target, "Default") and not migrating:
        selected = database[target]["Default"]
    else:
        selected = next((
            database["Install" + value]["Default"]
            for value in [previous, legacy_hash]
            if value and database.has_option("Install" + value, "Default")
        ), None)
        if selected is None:
            raise RuntimeError("Cannot identify Zen's previous default profile; select it in Zen before switching")
    resolved = (base / selected).resolve()
    if not resolved.is_relative_to((base / "Profiles").resolve()) or not resolved.is_dir():
        raise RuntimeError("Zen's selected profile is missing or outside its profile directory")

    if not database.has_option(target, "Default") or database[target]["Default"] != selected:
        installs = base / "installs.ini"
        old_installs = installs.read_text() if installs.is_file() else ""
        install_database = parser(old_installs)
        backup = state.parent / "zen-profile-backups" / new_hash
        backup.mkdir(parents=True, exist_ok=True, mode=0o700)
        for name, text in [("profiles.ini", original), ("installs.ini", old_installs)]:
            saved = backup / name
            if not saved.exists():
                saved.write_text(text)
                saved.chmod(0o600)
        database[target] = {"Default": selected, "Locked": "1"}
        install_database[new_hash] = {"Default": selected, "Locked": "1"}
        for path, value, expected in [(profiles, database, original), (installs, install_database, old_installs)]:
            output = io.StringIO()
            value.write(output, space_around_delimiters=False)
            if expected or path.exists():
                atomic_write(path, output.getvalue(), expected)
            else:
                atomic_write(path, output.getvalue())
    atomic_write(state, json.dumps({"hash": new_hash}) + "\n")
    return selected


def install_directory(app, literal=False):
    directory = Path(app) / "Contents/MacOS"
    return str(directory if literal else directory.resolve())


def main():
    args = argparse.ArgumentParser()
    args.add_argument("home")
    args.add_argument("app")
    args.add_argument("executable")
    args.add_argument("--literal-install-path", action="store_true")
    options = args.parse_args()
    home, app, executable = options.home, options.app, options.executable

    def install_hash(path, literal=False):
        directory = install_directory(path, literal)
        return subprocess.check_output([executable], input=directory.encode("utf-16le")).decode().strip()

    # Before activation the destination may still link to the old Nix bundle.
    # Hash the future normal path, while retaining the old resolved hash as a fallback.
    new_hash = install_hash(app, options.literal_install_path)
    profiles = Path(home) / "Library/Application Support/zen/profiles.ini"
    state = Path(home) / ".local/state/dotfiles/zen-install.json"
    previous = json.loads(state.read_text()).get("hash") if state.is_file() else None
    migrating = options.literal_install_path and previous and previous != new_hash
    if profiles.is_file() and (migrating or not parser(profiles.read_text()).has_option("Install" + new_hash, "Default")):
        running = subprocess.run(["/usr/bin/pgrep", "-u", str(os.getuid()), "-f", "/Zen.app/Contents/MacOS/zen"], capture_output=True)
        if running.returncode == 0:
            raise RuntimeError("Close Zen before changing its installation profile mapping")
    preserve(Path(home), new_hash, install_hash("/Applications/Zen.app"),
             prefer_previous=options.literal_install_path)
    print("Zen: existing profile selection preserved")


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        raise SystemExit(str(error)) from error
