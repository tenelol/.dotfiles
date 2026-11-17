"""Run from the repository root: python3 -m unittest modules/ghostty/tests/test_wallpaper_theme.py"""

import datetime
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest


FEATURE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("wallpaper_theme", FEATURE / "files/wallpaper-theme.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

# matugen's roles for one wallpaper, light and dark (--json hex).
ROLES = {
    "surface": ("#f6f9fe", "#101417"),
    "on_surface": ("#181c20", "#dfe3e8"),
    "on_surface_variant": ("#41474d", "#c1c7ce"),
    "outline": ("#71787e", "#8b9198"),
    "surface_container": ("#ebeef3", "#1c2024"),
    "surface_container_highest": ("#dfe3e8", "#313539"),
    "primary": ("#246488", "#94cdf7"),
    "on_primary": ("#ffffff", "#00344d"),
    "primary_container": ("#c8e6ff", "#004c6e"),
    "on_primary_container": ("#001e2f", "#c8e6ff"),
    "secondary": ("#4f606e", "#b7c9d9"),
    "tertiary": ("#64597c", "#cec0e8"),
    "error": ("#ba1a1a", "#ffb4ab"),
}
COLORS = {name: {"light": {"color": light}, "dark": {"color": dark}} for name, (light, dark) in ROLES.items()}


def desktop(day, provider="com.apple.wallpaper.choice.image", url="file:///Users/me/Pictures/a%20b.png"):
    return {
        "Desktop": {
            "LastUse": datetime.datetime(2026, 11, day),
            "Content": {
                "Choices": [{"Provider": provider, "Configuration": plistlib.dumps({"type": "imageFile", "url": {"relative": url}})}]
            },
        },
        "Idle": {"LastUse": datetime.datetime(2026, 12, 1), "Content": {"Choices": [{"Provider": "screen-saver"}]}},
    }


def settings(text):
    return dict(line.split(" = ", 1) for line in text.splitlines() if " = " in line and not line.startswith("palette"))


def palette(text):
    return [line.split("=")[-1] for line in text.splitlines() if line.startswith("palette = ")]


class WallpaperTests(unittest.TestCase):
    def test_the_desktop_shown_last_wins(self):
        index = {
            "SystemDefault": desktop(3, url="file:///old.png"),
            "Spaces": {"A": {"Default": desktop(9), "Displays": {"D": desktop(5, url="file:///other.png")}}},
        }
        self.assertEqual(module.current_wallpaper(index), Path("/Users/me/Pictures/a b.png"))

    def test_anything_but_an_image_file_is_no_wallpaper(self):
        self.assertIsNone(module.current_wallpaper({}))
        self.assertIsNone(module.current_wallpaper({"SystemDefault": desktop(1, provider="com.apple.wallpaper.choice.aerials")}))
        self.assertIsNone(module.current_wallpaper({"SystemDefault": desktop(1, url="https://example.com/a.png")}))
        broken = desktop(1)
        broken["Desktop"]["Content"]["Choices"][0]["Configuration"] = plistlib.dumps({"values": {}})
        self.assertIsNone(module.current_wallpaper({"SystemDefault": broken}))


class ThemeTests(unittest.TestCase):
    def test_each_mode_uses_its_own_roles(self):
        dark, light = module.theme(COLORS, "dark"), module.theme(COLORS, "light")
        self.assertEqual(settings(dark)["background"], "#101417")
        self.assertEqual(settings(dark)["foreground"], "#dfe3e8")
        self.assertEqual(settings(dark)["cursor-color"], "#94cdf7")
        self.assertEqual(settings(light)["background"], "#f6f9fe")
        self.assertEqual(settings(light)["selection-background"], "#c8e6ff")
        self.assertEqual(len(palette(dark)), 16)
        # Red is the error role and blue, which Neovim and the shaders use as the accent, the tertiary.
        self.assertEqual(palette(dark)[1], "#ffb4ab")
        self.assertEqual(palette(dark)[4], "#cec0e8")

    def test_every_text_color_reads_on_the_background(self):
        faint = {name: dict(modes) for name, modes in COLORS.items()}
        for name in ("error", "primary", "secondary", "tertiary", "outline"):
            faint[name] = {"light": {"color": "#f0f3f8"}, "dark": {"color": "#161a1d"}}
        for colors in (COLORS, faint):
            for mode in ("light", "dark"):
                text = module.theme(colors, mode)
                for color in palette(text)[1:]:
                    self.assertGreaterEqual(module.contrast(color, settings(text)["background"]), module.MIN_CONTRAST)

    def test_neovim_gets_every_role_its_reader_needs(self):
        text = module.nvim_palette(COLORS, "dark")
        roles = dict(line.split("=", 1) for line in text.splitlines() if not line.startswith("#"))
        reader = (FEATURE.parent / "nvim/files/lua/core/wallpaper-palette.lua").read_text()
        needed = reader.split("local ROLES = {", 1)[1].split("}", 1)[0].replace('"', "").replace(",", "").split()
        self.assertGreaterEqual(len(needed), 14)
        for name in needed:
            self.assertRegex(roles[name], r"^#[0-9a-f]{6}$", name)
        self.assertEqual(roles["mode"], "dark")
        self.assertEqual(roles["background"], "#101417")
        self.assertEqual(roles["ansi4"], palette(module.theme(COLORS, "dark"))[4])
        self.assertEqual(module.nvim_palette(COLORS, "light").splitlines()[1], "mode=light")

    def test_files_are_written_once_and_left_to_omniwm(self):
        with tempfile.TemporaryDirectory() as temporary:
            themes = Path(temporary) / "themes"
            rendered = Path(temporary) / "theme/omniwm-palette"
            write = lambda: module.write_themes(COLORS, themes, rendered, "dark")
            self.assertTrue(write())
            self.assertEqual(rendered.read_text(), module.nvim_palette(COLORS, "dark"))
            dark = themes / "omniwm-dark"
            self.assertEqual(dark.read_text(), module.theme(COLORS, "dark"))
            self.assertEqual(sorted(path.name for path in themes.iterdir()), ["omniwm-dark", "omniwm-light"])

            before = dark.stat().st_ino
            self.assertFalse(write())
            self.assertEqual(dark.stat().st_ino, before)

            # A seed from the static palette is replaced; a theme OmniWM wrote is not.
            dark.write_text("foreground = c9d4e3\n")
            self.assertTrue(write())
            owned = "# Generated by OmniWM from its dark palette.\nbackground = #000000\n"
            dark.write_text(owned)
            (themes / "omniwm-light").write_text("foreground = c9d4e3\n")
            self.assertIsNone(write())
            self.assertEqual(dark.read_text(), owned)
            self.assertEqual((themes / "omniwm-light").read_text(), "foreground = c9d4e3\n")

            # The same goes for a palette OmniWM rendered from its template.
            dark.write_text("foreground = c9d4e3\n")
            rendered.write_text("# OmniWM App Theming template\nmode=dark\n")
            self.assertIsNone(write())
            self.assertEqual(dark.read_text(), "foreground = c9d4e3\n")


if __name__ == "__main__":
    unittest.main()
