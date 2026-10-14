"""Run with python3; target detection must not depend on a managed wallpaper."""

import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[3]


def function(path, name):
    source = (ROOT / path).read_text()
    return name + "() {" + source.split(name + "() {", 1)[1].split("\n}\n", 1)[0] + "\n}"


doctor = function("modules/dotfiles-doctor/files/dotfiles-doctor", "check_darwin_desktop")
raycast = function(
    "modules/raycast/files/scripts/dotfiles-rebuild-macbook.sh", "detect_target_configuration"
).replace("/usr/bin/pgrep", "pgrep")
stubs = """
set -eu
uname_s=Darwin
has() { return 0; }
section() { :; }
status() { printf '%s %s %s\\n' "$@"; }
pgrep() { [ "$2" = "$RUNNING_WM" ]; }
"""

cases = [
    ("", "", "mac"),
    ("", ".config/aerospace/aerospace.toml", "aerospace"),
    ("", ".config/rift/config.toml", "rift"),
    ("", "Library/LaunchAgents/org.nix-community.home.omniwm.plist", "omniwm"),
    ("OmniWM", ".config/rift/config.toml", "omniwm"),
    ("AeroSpace", ".config/rift/config.toml", "aerospace"),
    ("rift", ".config/aerospace/aerospace.toml", "rift"),
    ("rift", "Library/LaunchAgents/org.nix-community.home.omniwm.plist", "rift"),
    ("", ".config/omniwm/settings.toml", "mac"),
    ("Rift", "", "rift"),
]

for running, config, expected in cases:
    # Old links can remain until activation; they must not affect the target.
    for wallpaper in (None, "wallpaper.png", "aerospace.png", "rift.png"):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            if config:
                path = home / config
                path.parent.mkdir(parents=True)
                path.touch()
            if wallpaper:
                image = home / wallpaper
                image.touch()
                link = home / ".config/theme/wallpaper.png"
                link.parent.mkdir(parents=True)
                link.symlink_to(image)
            env = dict(os.environ, HOME=directory, RUNNING_WM=running)
            for source, call in (
                (doctor, "check_darwin_desktop"),
                (raycast, "detect_target_configuration"),
            ):
                output = subprocess.check_output(
                    ["bash", "-c", stubs + source + "\n" + call], env=env, text=True
                )
                assert "macbook-" + expected in output, (running, config, wallpaper, output)
                assert "wallpaper" not in output, output

print(f"Darwin target detection: {len(cases) * 4 * 2} checks passed")
