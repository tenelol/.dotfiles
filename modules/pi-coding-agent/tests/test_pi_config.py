import json
import re
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


FILES = Path(__file__).resolve().parents[1] / "files"
FORBIDDEN_NAMES = {
    "auth.json",
    "models-store.json",
    "trust.json",
    "web-search.json",
    "missions",
    "npm",
    "sessions",
    "web-search-cache",
}
SENSITIVE_KEYS = re.compile(r"(?:api.?key|auth|credential|password|secret|token)", re.IGNORECASE)
EXPECTED_EXTENSIONS = {
    "pi-plan-mode",
    "pi-subagents",
    "pi-tool-display",
    "pi-vim",
    "pi-web-access",
    "pi-zentui",
    "playwright-cli",
    "ponytail",
    "rpiv-ask-user-question",
    "rpiv-todo",
}


def keys(value):
    if isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from keys(child)
    elif isinstance(value, list):
        for child in value:
            yield from keys(child)


class PiConfigTests(unittest.TestCase):
    def test_runtime_state_and_credentials_are_not_copied(self):
        self.assertFalse(FORBIDDEN_NAMES.intersection(path.name for path in FILES.iterdir()))
        for path in (FILES / "settings.json", FILES / "models.json"):
            self.assertFalse(
                [key for key in keys(json.loads(path.read_text())) if SENSITIVE_KEYS.search(key)],
                path,
            )

    def test_extensions_remain_editable_local_sources(self):
        settings = json.loads((FILES / "settings.json").read_text())
        self.assertEqual(settings["packages"], [])
        extensions = FILES / "extensions"
        self.assertTrue(all((extensions / name / "package.json").is_file() for name in EXPECTED_EXTENSIONS))
        self.assertFalse((extensions / "playwright-cli.ts").exists())
        self.assertTrue((FILES / "disabled-extensions/compact-shell/index.ts").is_file())

    def test_config_merge_preserves_runtime_fields(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            target = root / "settings.json"
            declared = root / "declared.json"
            target.write_text('{"lastChangelogVersion":"0.85.1","theme":"old"}')
            declared.write_text('{"theme":"managed","packages":["npm:example@1.0.0"]}')

            subprocess.run(
                [FILES / "merge-json-config.sh", target, declared],
                check=True,
            )

            self.assertEqual(
                json.loads(target.read_text()),
                {
                    "lastChangelogVersion": "0.85.1",
                    "theme": "managed",
                    "packages": ["npm:example@1.0.0"],
                },
            )
            self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)

    def test_source_link_refuses_to_replace_regular_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"
            target = root / "target"
            source.write_text("source")

            subprocess.run([FILES / "link-source.sh", source, target], check=True)
            self.assertEqual(target.resolve(), source.resolve())

            target.unlink()
            target.write_text("keep")
            result = subprocess.run(
                [FILES / "link-source.sh", source, target],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(target.read_text(), "keep")


if __name__ == "__main__":
    unittest.main()
