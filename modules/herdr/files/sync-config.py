#!/usr/bin/env python3
"""Install herdr's config as a regular file, keeping the live [theme.custom].

OmniWM App Theming rewrites that one table in place and refuses to write
through a link into the Nix store. Everything else still comes from the
repository on every switch.
"""

import os
from pathlib import Path
import re
import sys
import tempfile

HEADER = re.compile(r"^[ \t]*\[[ \t]*theme[ \t]*\.[ \t]*custom[ \t]*\][ \t]*(#.*)?$")


def table_span(lines):
    """Line range of [theme.custom]: its header through its last key.

    This is the text OmniWM fingerprints, so it has to survive byte for byte.
    Comments and blank lines after the last key belong to the file around it.
    The table holds one-line color strings only.
    """
    start = next((i for i, line in enumerate(lines) if HEADER.match(line.rstrip("\r\n"))), None)
    if start is None:
        return None
    end = start + 1
    for i in range(start + 1, len(lines)):
        stripped = lines[i].strip()
        if stripped.startswith("["):
            break
        if stripped and not stripped.startswith("#"):
            end = i + 1
    return start, end


def merge(source, live):
    """The repository's config with the live file's color table, if it has one."""
    if live is None:
        return source
    live_lines = live.splitlines(keepends=True)
    live_span = table_span(live_lines)
    if live_span is None:
        return source
    table = live_lines[live_span[0] : live_span[1]]
    if not table[-1].endswith("\n"):
        table[-1] += "\n"
    source_lines = source.splitlines(keepends=True)
    source_span = table_span(source_lines)
    if source_span is None:
        gap = "" if not source or source.endswith("\n\n") else "\n" if source.endswith("\n") else "\n\n"
        return source + gap + "".join(table)
    return "".join(source_lines[: source_span[0]] + table + source_lines[source_span[1] :])


def sync(source_path, target_path):
    source = source_path.read_text()
    live = None
    if target_path.is_symlink():
        # A link left by the static setup; its colors are the repository's own.
        target_path.unlink()
    elif target_path.exists():
        live = target_path.read_text()
    merged = merge(source, live)
    if merged == live:
        return
    target_path.parent.mkdir(parents=True, exist_ok=True)
    staged = None
    try:
        with tempfile.NamedTemporaryFile("w", dir=target_path.parent, delete=False) as output:
            staged = Path(output.name)
            output.write(merged)
            output.flush()
            os.fsync(output.fileno())
        staged.chmod(0o644)
        os.replace(staged, target_path)
    finally:
        if staged is not None:
            staged.unlink(missing_ok=True)


if __name__ == "__main__":
    sync(Path(sys.argv[1]), Path(sys.argv[2]))
