#!/usr/bin/env python3
"""Continue a substantive turn once when its final Vault capture review was skipped."""

from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any


STATE_DIR = Path(os.environ.get("VAULT_CAPTURE_GATE_STATE_DIR", "/tmp/codex-vault-capture-gate"))
TURN_ID = re.compile(r"^[A-Za-z0-9._:-]{1,200}$")
REVIEW_MARKER = "<!-- vault-capture-gate: reviewed -->"
MAX_AGE_SECONDS = 24 * 60 * 60


def state_path(turn_id: str) -> Path | None:
    return STATE_DIR / f"{turn_id}.required" if TURN_ID.fullmatch(turn_id) else None


def cleanup() -> None:
    if not STATE_DIR.is_dir():
        return
    cutoff = time.time() - MAX_AGE_SECONDS
    for path in STATE_DIR.glob("*.required"):
        try:
            if path.stat().st_mtime < cutoff:
                path.unlink()
        except OSError:
            continue


def decision_for(payload: dict[str, Any], required: bool) -> dict[str, str]:
    if not required:
        return {}
    message = payload.get("last_assistant_message")
    if isinstance(message, str) and (REVIEW_MARKER in message or "Vault保存:" in message):
        return {}
    if payload.get("stop_hook_active") is True:
        return {}
    return {
        "decision": "block",
        "reason": (
            "最終回答の直前に、AGENTS.mdの最終capture gateを一度だけ実行してください。"
            "保存価値・重複・現在証拠を判定し、必要ならsanitized raw→canonical→receiptを保存・確認してください。"
            f"完了後の最終Markdown末尾へ `{REVIEW_MARKER}` を追加してください。"
        ),
    }


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, OSError):
        return 0
    if not isinstance(payload, dict):
        return 0
    cleanup()
    turn_id = payload.get("turn_id")
    path = state_path(turn_id) if isinstance(turn_id, str) else None
    required = bool(path and path.is_file())
    decision = decision_for(payload, required)
    if required and not decision and path is not None:
        try:
            path.unlink()
        except OSError:
            pass
    if decision:
        json.dump(decision, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
