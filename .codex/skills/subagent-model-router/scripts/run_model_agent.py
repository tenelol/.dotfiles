#!/usr/bin/env python3
"""Run one bounded Codex worker with an explicit model and reasoning effort."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any


ROUTES: dict[str, dict[str, Any]] = {
    "fast": {
        "models": ["gpt-5.6-luna", "gpt-5.4-mini", "gpt-5.3-codex-spark"],
        "effort": "low",
    },
    "standard": {
        "models": ["gpt-5.6-terra", "gpt-5.5", "gpt-5.4"],
        "effort": "medium",
    },
    "deep": {
        "models": ["gpt-5.6-sol", "gpt-5.5", "gpt-5.4"],
        "effort": "xhigh",
    },
    "review": {
        "models": ["gpt-5.6-sol", "gpt-5.5", "gpt-5.4"],
        "effort": "max",
    },
}

ENV_MODEL = {
    "fast": "CODEX_SUBAGENT_MODEL_FAST",
    "standard": "CODEX_SUBAGENT_MODEL_STANDARD",
    "deep": "CODEX_SUBAGENT_MODEL_DEEP",
    "review": "CODEX_SUBAGENT_MODEL_REVIEW",
}

EFFORTS = ("none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra")

LEAF_CONTRACT = """You are a bounded model-routed leaf worker.
Complete only the assigned packet. Do not spawn, delegate to, or coordinate additional agents.
Respect all repository instructions and the stated write scope. Do not modify files unless the packet explicitly authorizes it and the sandbox allows it.
Return a concise result with outcome, evidence, files changed, checks run, and remaining risks or blockers.

Assigned packet:
"""


class RouterError(RuntimeError):
    """A user-actionable routing error."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a bounded Codex worker with an explicit model argument."
    )
    parser.add_argument("--tier", choices=ROUTES, default="standard")
    parser.add_argument("--model", help="Explicit model slug; overrides the selected tier.")
    parser.add_argument("--reasoning-effort", choices=EFFORTS)
    parser.add_argument("--cwd", default=os.getcwd(), help="Worker directory.")
    parser.add_argument(
        "--sandbox",
        choices=("read-only", "workspace-write"),
        default="read-only",
    )
    parser.add_argument(
        "--allow-write",
        action="store_true",
        help="Required acknowledgement for workspace-write workers.",
    )
    prompt_group = parser.add_mutually_exclusive_group()
    prompt_group.add_argument("--prompt")
    prompt_group.add_argument("--prompt-file")
    parser.add_argument("--output", help="Optional file for the worker's final message.")
    parser.add_argument("--timeout-seconds", type=int, default=1800)
    parser.add_argument("--codex-bin", default=os.environ.get("CODEX_BIN", "codex"))
    parser.add_argument("--no-contract", action="store_true")
    parser.add_argument("--skip-git-repo-check", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--list-routes", action="store_true")
    return parser.parse_args()


def load_catalog(codex_bin: str) -> dict[str, dict[str, Any]]:
    try:
        completed = subprocess.run(
            [codex_bin, "debug", "models"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RouterError(f"Could not load the Codex model catalog: {exc}") from exc

    if completed.returncode != 0:
        detail = completed.stderr.strip() or completed.stdout.strip()
        raise RouterError(f"Could not load the Codex model catalog: {detail}")

    try:
        payload = json.loads(completed.stdout)
        return {
            item["slug"]: item
            for item in payload.get("models", [])
            if item.get("slug") and item.get("visibility") != "hide"
        }
    except (json.JSONDecodeError, TypeError, KeyError) as exc:
        raise RouterError("Codex returned an invalid model catalog.") from exc


def supported_efforts(model: dict[str, Any]) -> set[str]:
    values = model.get("supported_reasoning_levels") or model.get(
        "supported_reasoning_efforts"
    ) or []
    efforts: set[str] = set()
    for value in values:
        if isinstance(value, str):
            efforts.add(value)
        elif isinstance(value, dict) and isinstance(value.get("effort"), str):
            efforts.add(value["effort"])
    return efforts


def resolve_route(
    args: argparse.Namespace, catalog: dict[str, dict[str, Any]]
) -> tuple[str, str]:
    explicit_model = args.model or os.environ.get(ENV_MODEL[args.tier])
    if explicit_model:
        model = explicit_model
        if model not in catalog:
            available = ", ".join(sorted(catalog)) or "none"
            raise RouterError(
                f"Model '{model}' is not picker-visible. Available models: {available}"
            )
    else:
        model = next(
            (candidate for candidate in ROUTES[args.tier]["models"] if candidate in catalog),
            "",
        )
        if not model:
            raise RouterError(
                f"No catalog model matches tier '{args.tier}'. Pass --model explicitly."
            )

    effort = args.reasoning_effort or ROUTES[args.tier]["effort"]
    if effort == "ultra":
        raise RouterError(
            "Ultra reasoning is not allowed for bounded CLI leaf workers because it can "
            "trigger recursive delegation. Use max or lower."
        )

    model_info = catalog.get(model)
    if model_info:
        efforts = supported_efforts(model_info)
        if efforts and effort not in efforts:
            raise RouterError(
                f"Model '{model}' does not support effort '{effort}'. "
                f"Supported efforts: {', '.join(sorted(efforts))}"
            )
    return model, effort


def load_prompt(args: argparse.Namespace) -> str:
    if args.prompt is not None:
        prompt = args.prompt
    elif args.prompt_file:
        try:
            prompt = Path(args.prompt_file).expanduser().read_text(encoding="utf-8")
        except OSError as exc:
            raise RouterError(f"Could not read prompt file: {exc}") from exc
    elif not sys.stdin.isatty():
        prompt = sys.stdin.read()
    else:
        raise RouterError("Provide --prompt, --prompt-file, or prompt text on stdin.")

    if not prompt.strip():
        raise RouterError("The worker prompt is empty.")
    return prompt if args.no_contract else f"{LEAF_CONTRACT}{prompt}"


def is_git_repo(cwd: Path) -> bool:
    completed = subprocess.run(
        ["git", "-C", str(cwd), "rev-parse", "--is-inside-work-tree"],
        check=False,
        capture_output=True,
        text=True,
    )
    return completed.returncode == 0 and completed.stdout.strip() == "true"


def build_command(
    args: argparse.Namespace,
    model: str,
    effort: str,
    cwd: Path,
    output_path: str,
) -> list[str]:
    command = [
        args.codex_bin,
        "--ask-for-approval",
        "never",
        "exec",
        "--model",
        model,
        "-c",
        f'model_reasoning_effort="{effort}"',
        "--sandbox",
        args.sandbox,
        "--ephemeral",
        "--disable",
        "multi_agent",
        "--disable",
        "multi_agent_v2",
        "--color",
        "never",
        "--output-last-message",
        output_path,
        "-C",
        str(cwd),
    ]
    if args.skip_git_repo_check or not is_git_repo(cwd):
        command.append("--skip-git-repo-check")
    command.append("-")
    return command


def list_routes(catalog: dict[str, dict[str, Any]], args: argparse.Namespace) -> int:
    resolved: dict[str, Any] = {}
    for tier in ROUTES:
        tier_args = argparse.Namespace(**vars(args))
        tier_args.tier = tier
        tier_args.model = None
        tier_args.reasoning_effort = None
        try:
            model, effort = resolve_route(tier_args, catalog)
            resolved[tier] = {"model": model, "reasoning_effort": effort}
        except RouterError as exc:
            resolved[tier] = {"error": str(exc)}
    print(json.dumps(resolved, indent=2, sort_keys=True))
    return 0


def main() -> int:
    args = parse_args()
    if args.sandbox == "workspace-write" and not args.allow_write:
        raise RouterError(
            "workspace-write requires --allow-write after assigning a disjoint write set or worktree."
        )
    if args.timeout_seconds <= 0:
        raise RouterError("--timeout-seconds must be positive.")

    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        raise RouterError(f"Worker directory does not exist: {cwd}")

    catalog = load_catalog(args.codex_bin)
    if args.list_routes:
        return list_routes(catalog, args)

    model, effort = resolve_route(args, catalog)
    prompt = load_prompt(args)

    owned_temp = args.output is None
    if owned_temp:
        handle = tempfile.NamedTemporaryFile(prefix="codex-model-agent-", delete=False)
        handle.close()
        output_path = Path(handle.name)
    else:
        output_path = Path(args.output).expanduser().resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)

    command = build_command(args, model, effort, cwd, str(output_path))
    if args.dry_run:
        if owned_temp:
            output_path.unlink(missing_ok=True)
        print(
            json.dumps(
                {
                    "tier": args.tier,
                    "model": model,
                    "reasoning_effort": effort,
                    "sandbox": args.sandbox,
                    "cwd": str(cwd),
                    "prompt_bytes": len(prompt.encode("utf-8")),
                    "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest(),
                    "command": command,
                },
                indent=2,
            )
        )
        return 0

    try:
        completed = subprocess.run(
            command,
            input=prompt,
            check=False,
            capture_output=True,
            text=True,
            timeout=args.timeout_seconds,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise RouterError(f"Codex worker failed to run: {exc}") from exc

    try:
        if completed.returncode != 0:
            if completed.stdout:
                sys.stderr.write(completed.stdout)
            if completed.stderr:
                sys.stderr.write(completed.stderr)
            return completed.returncode

        final_message = output_path.read_text(encoding="utf-8").strip()
        if not final_message:
            raise RouterError("Codex worker completed without a final message.")
        print(final_message)
        return 0
    finally:
        if owned_temp:
            output_path.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RouterError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(2)
