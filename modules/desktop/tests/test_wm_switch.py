"""Check macOS WM handover without calling the host's launchctl or pkill."""

import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[3]
scripts = json.loads(subprocess.check_output([
    "nix", "eval", "--impure", "--json",
    "--file", "modules/desktop/tests/default.nix-test", "preActivation",
], cwd=ROOT, text=True))

stops = {
    "rift": (["git.acsandmann.rift", "org.nixos.rift", "homebrew.mxcl.rift"], ["rift", "Rift"]),
    "aerospace": (["org.nixos.aerospace"], ["AeroSpace", "aerospace"]),
    "autoraise": (["org.nixos.autoraise"], ["AutoRaise", "autoraise"]),
    "omniwm": (["org.nix-community.home.omniwm"], ["OmniWM"]),
}
running = {
    "native": set(),
    "rift": {"rift"},
    "aerospace": {"aerospace", "autoraise"},
    "omniwm": {"omniwm"},
}


def expected(backend: str) -> list[list[str]]:
    calls = []
    for provider, (labels, processes) in stops.items():
        if provider in running[backend]:
            continue
        calls.append(["id", "-u", "fixture"])
        calls += [["launchctl", "bootout", f"gui/501/{label}"] for label in labels]
        calls += [["pkill", "-u", "fixture", "-x", name] for name in processes]
    return calls


assert scripts.keys() == running.keys(), scripts.keys()

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    log = root / "calls"
    for name in ("id", "launchctl", "pkill"):
        path = root / name
        path.write_text(
            "#!/bin/sh\n"
            f"printf '%s\\n' \"{name} $*\" >> \"$CALLS\"\n"
            + ("printf '501\\n'\n" if name == "id" else 'exit "$MOCK_STATUS"\n')
        )
        path.chmod(0o700)
    for backend, script in scripts.items():
        for status in ("0", "1"):
            log.write_text("")
            safe = script.replace("probe", "fixture")
            safe = safe.replace("/usr/bin/id", str(root / "id"))
            safe = safe.replace("/bin/launchctl", str(root / "launchctl"))
            safe = safe.replace("/usr/bin/pkill", str(root / "pkill"))
            subprocess.run(["/bin/sh", "-eu", "-c", safe], check=True,
                           env={**os.environ, "CALLS": str(log), "MOCK_STATUS": status})
            calls = [line.split() for line in log.read_text().splitlines()]
            # Module merge order is not part of the contract; compare per provider.
            assert sorted(calls) == sorted(expected(backend)), (backend, status, calls)

print("WM handover: every rice stops exactly the window managers it does not run")
