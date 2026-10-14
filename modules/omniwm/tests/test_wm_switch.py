"""Check WM handover without calling the host's launchctl or pkill."""

import json
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[3]
scripts = json.loads(subprocess.check_output([
    "nix-instantiate", "--eval", "--strict", "--json", "--expr", """
let
  module = import ./modules/omniwm/default.nix {
    delib = {
      scopedModule = value: value;
      moduleOptions = value: value;
      readOnly = value: value;
      boolOption = value: value;
    };
    desktopSelection.omniwm = true;
    hostTraits.darwinDesktop = true;
    lib.mkAfter = value: value;
    pkgs = {};
    profile.username = "fixture";
  };
in {
  enable = module.darwin.ifEnabled.system.activationScripts.preActivation.text;
  disable = module.darwin.ifDisabled.system.activationScripts.preActivation.text;
}
"""], cwd=ROOT, text=True))

labels = ["git.acsandmann.rift", "org.nixos.rift", "homebrew.mxcl.rift",
          "org.nixos.aerospace", "org.nixos.autoraise"]
processes = ["rift", "Rift", "AeroSpace", "aerospace", "AutoRaise", "autoraise"]
expected = {
    "enable": [["id", "-u", "fixture"]]
              + [["launchctl", "bootout", f"gui/501/{label}"] for label in labels]
              + [["pkill", "-u", "fixture", "-x", name] for name in processes],
    "disable": [["id", "-u", "fixture"],
                ["launchctl", "bootout", "gui/501/org.nix-community.home.omniwm"],
                ["pkill", "-u", "fixture", "-x", "OmniWM"]],
}

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
    for name, script in scripts.items():
        for status in ("0", "1"):
            log.write_text("")
            safe = script.replace("/usr/bin/id", str(root / "id"))
            safe = safe.replace("/bin/launchctl", str(root / "launchctl"))
            safe = safe.replace("/usr/bin/pkill", str(root / "pkill"))
            subprocess.run(["/bin/sh", "-eu", "-c", safe], check=True,
                           env={**os.environ, "CALLS": str(log), "MOCK_STATUS": status})
            calls = [line.split() for line in log.read_text().splitlines()]
            assert calls == expected[name], (name, status, calls)

print("WM handover: both directions preserve stop order and tolerate absent processes")
