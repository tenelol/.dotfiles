#!/usr/bin/env python3
"""Mark substantive turns so the Stop hook can enforce one final capture review."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


STATE_DIR = Path(os.environ.get("VAULT_CAPTURE_GATE_STATE_DIR", "/tmp/codex-vault-capture-gate"))
TURN_ID = re.compile(r"^[A-Za-z0-9._:-]{1,200}$")
REVIEW_MARKER = "<!-- vault-capture-gate: reviewed -->"
TRIVIAL = re.compile(r"^\s*(?:hi|hello|hey|こんにちは|こんばんは|おはよう|ありがとう|thanks|はい|いいえ|ok|okay|了解)[。.!！\s]*$", re.IGNORECASE)
OPT_OUT = re.compile(r"(?:vault|obsidian|コンテクスト).*(?:不要|見ない|使わない)|do not (?:load|use|search).*(?:vault|context)", re.IGNORECASE)


def is_substantive(prompt: str) -> bool:
    return bool(prompt.strip()) and not TRIVIAL.fullmatch(prompt) and not OPT_OUT.search(prompt)


def state_path(turn_id: str) -> Path | None:
    return STATE_DIR / f"{turn_id}.required" if TURN_ID.fullmatch(turn_id) else None


def mark_required(turn_id: str) -> bool:
    path = state_path(turn_id)
    if path is None:
        return False
    STATE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    path.write_text("required\n", encoding="utf-8")
    path.chmod(0o600)
    return True


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    prompt = payload.get("prompt") if isinstance(payload, dict) else None
    turn_id = payload.get("turn_id") if isinstance(payload, dict) else None
    if not isinstance(prompt, str) or not is_substantive(prompt):
        return 0
    if isinstance(turn_id, str):
        mark_required(turn_id)
    additional = (
        "Final Vault capture guard is active for this substantive turn. Immediately before the final response, "
        "run the AGENTS.md final capture gate exactly once. After the gate is reviewed (whether saved or intentionally "
        f"not saved), append `{REVIEW_MARKER}` to the final Markdown; it is an invisible completion marker."
    )
    json.dump({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": additional}}, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
