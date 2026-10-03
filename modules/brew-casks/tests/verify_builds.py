#!/usr/bin/env python3
"""Verify built app bundles, signatures, CLI links and completion files."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("metadata", type=Path)
    parser.add_argument("build_results", type=Path)
    args = parser.parse_args()

    manifest = json.loads((Path(__file__).parent.parent / "files/apps.json").read_text())
    specs = {app["name"]: app for app in manifest["base"] + manifest["fullDesktop"]}
    metadata = json.loads(args.metadata.read_text())
    outputs = {result["drvPath"]: Path(result["outputs"]["out"])
               for result in json.loads(args.build_results.read_text())}
    assert set(specs) == {item["name"] for item in metadata}
    expected = {item["drvPath"] for item in metadata}
    expected.update(item["completionDrvPath"] for item in metadata if "completionDrvPath" in item)
    assert set(outputs) == expected

    failures = []
    version_arguments = {
        "blender": ["--version"],
        "cursor": ["--version"],
        "ghostty": ["+version"],
        "zed": ["--version"],
        "zen": ["--version"],
        "code": ["--version"],
        "code-tunnel": ["--version"],
    }
    for item in metadata:
        name = item["name"]
        spec = specs[name]
        output = outputs[item["drvPath"]]
        bundle = output / "Applications" / item["sourceRoot"]
        try:
            with (bundle / "Contents/Info.plist").open("rb") as stream:
                info = plistlib.load(stream)
            # DB Browser's upstream plist has an empty CFBundleExecutable;
            # brew-nix resolves its executable from the app name instead.
            executable_name = info.get("CFBundleExecutable") or bundle.stem
            executable = bundle / "Contents/MacOS" / executable_name
            assert executable.is_file(), f"Missing bundle executable: {executable}"
            signature = subprocess.run(
                ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(bundle)],
                capture_output=True, text=True, timeout=90,
            )
            assert signature.returncode == 0, signature.stderr.strip()
            for command, source in spec.get("cli", {}).items():
                link = output / "bin" / command
                if spec.get("wrapCli", False):
                    assert not link.is_symlink(), f"CLI needs an executable wrapper: {command}"
                    assert str(output / "Applications" / source).encode() in link.read_bytes(), command
                else:
                    assert link.is_symlink(), f"CLI is not linked: {command}"
                    assert link.resolve() == (output / "Applications" / source).resolve(), command
                assert os.access(link, os.X_OK), f"CLI is not executable: {command}"
                if command in version_arguments:
                    version = subprocess.run(
                        [str(link), *version_arguments[command]],
                        capture_output=True, text=True, timeout=30,
                    )
                    assert version.returncode == 0, f"{command}: {version.stderr.strip()}"
                    assert version.stdout.strip(), f"{command}: no version output"
            for target, source in spec.get("extraFiles", {}).items():
                link = output / target
                assert link.is_symlink(), target
                assert link.resolve() == (output / "Applications" / source).resolve(), target
                assert link.stat().st_size > 0, target
            for shells in spec.get("completions", {}).values():
                for target in shells.values():
                    assert (outputs[item["completionDrvPath"]] / target).stat().st_size > 0, target
            print(f"PASS {name}: {info['CFBundleIdentifier']}, signed bundle and integration files", flush=True)
        except (AssertionError, OSError, KeyError, subprocess.TimeoutExpired) as error:
            failures.append(name)
            print(f"FAIL {name}: {error}", flush=True)
    if failures:
        raise SystemExit("Failed: " + ", ".join(failures))
    print(f"Verified {len(metadata)} apps")


if __name__ == "__main__":
    main()
