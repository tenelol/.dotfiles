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
        self.assertFalse(FORBIDDEN_NAMES.intersection(path.name for path in FILES.rglob("*")))
        for path in (FILES / "settings.json", FILES / "models.json"):
            self.assertFalse(
                [key for key in keys(json.loads(path.read_text())) if SENSITIVE_KEYS.search(key)],
                path,
            )

    def test_packages_are_pinned(self):
        packages = json.loads((FILES / "settings.json").read_text())["packages"]
        self.assertTrue(packages)
        self.assertTrue(all(re.fullmatch(r"npm:.+@\d+\.\d+\.\d+", package) for package in packages))

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


if __name__ == "__main__":
    unittest.main()
