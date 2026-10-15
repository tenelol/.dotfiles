#!/usr/bin/env python3
"""Compile local Ghostty shaders and check the config only references deployed ones.

Run: nix shell nixpkgs#glslang -c python3 modules/ghostty/tests/test_shaders.py
"""

from __future__ import annotations

from pathlib import Path
import re
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).resolve().parent.parent
PREFIX = (MODULE / "tests/shadertoy_prefix.glsl").read_text()
# The Nix module prepends the shared HUD helpers to every local effect.
HUD = (MODULE / "files/shaders/hud_common.glsl").read_text()


class ShaderTest(unittest.TestCase):
    def test_local_shaders_compile(self) -> None:
        shaders = sorted(p for p in (MODULE / "files/shaders").glob("*.glsl") if p.name != "hud_common.glsl")
        self.assertTrue(shaders)
        with tempfile.TemporaryDirectory() as tmp:
            for shader in shaders:
                with self.subTest(shader=shader.name):
                    frag = Path(tmp) / f"{shader.stem}.frag"
                    frag.write_text(PREFIX + HUD + "\n" + shader.read_text())
                    result = subprocess.run(
                        ["glslangValidator", "-G", "-o", str(Path(tmp) / "out.spv"), str(frag)],
                        capture_output=True,
                        text=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_configured_shaders_are_deployed(self) -> None:
        module = (MODULE / "default.nix").read_text()
        deployed = set(re.findall(r'"ghostty/shaders/([^"]+)"\.source', module))
        for config in ("config", "config-darwin"):
            text = (MODULE / "files" / config).read_text()
            for name in re.findall(r"^#? ?custom-shader = ~/\.config/ghostty/shaders/(\S+)$", text, re.M):
                with self.subTest(config=config, shader=name):
                    self.assertIn(name, deployed)


if __name__ == "__main__":
    unittest.main()
