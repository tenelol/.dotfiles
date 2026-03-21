#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--root", required=True)
    return parser.parse_args()


def scan_latest(root: Path) -> float:
    latest = 0.0
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d != ".git"]
        for name in files:
            if not name.endswith((".scss", ".sass")):
                continue
            path = Path(base) / name
            try:
                latest = max(latest, path.stat().st_mtime)
            except FileNotFoundError:
                continue
    return latest


def compile_once(input_path: Path, output_path: Path) -> bool:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["sassc", str(input_path), str(output_path)],
        capture_output=True,
        text=True,
    )

    if result.stdout:
        sys.stdout.write(result.stdout)
    if result.stderr:
        sys.stderr.write(result.stderr)

    return result.returncode == 0


def main():
    args = parse_args()
    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    root = Path(args.root).resolve()

    if not input_path.exists():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    last_mtime = 0.0
    while True:
        current = scan_latest(root)
        if current > last_mtime:
            if compile_once(input_path, output_path):
                print(
                    f"[scss-watch] compiled {input_path} -> {output_path}", flush=True
                )
            last_mtime = current
        time.sleep(0.4)


if __name__ == "__main__":
    main()
