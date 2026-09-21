"""Conservative contrast selection; image sampling uses only generated local files."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("wallpaper_contrast", Path(__file__).resolve().parents[1] / "wallpaper_contrast.py")
contrast = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contrast)


class RecommendationTests(unittest.TestCase):
    def test_only_extreme_contrast_triggers(self):
        text, tint = (220, 215, 186), (31, 31, 40)
        self.assertLess(contrast.recommend([(240, 230, 205)] * 100, text, tint, 70), 70)
        self.assertLessEqual(contrast.recommend([(240, 230, 205)] * 100, text, tint, 70), 12)
        self.assertEqual(contrast.recommend([(12, 110, 130)] * 100, text, tint, 70), 70)
        self.assertEqual(contrast.recommend([(240, 230, 205)] * 20 + [(25, 35, 40)] * 80, text, tint, 70), 70)
        self.assertEqual(contrast.recommend([], text, tint, 70), 70)

    def test_light_themes_and_unrepairable_custom_colors(self):
        self.assertEqual(contrast.recommend([(250, 245, 230)] * 100, (20, 20, 20), (245, 245, 240), 70), 70)
        self.assertEqual(contrast.recommend([(245, 235, 210)] * 100, (76, 79, 105), (239, 241, 245), 70), 70)
        self.assertLess(contrast.recommend([(10, 10, 10)] * 100, (20, 20, 20), (245, 245, 240), 85), 85)
        self.assertEqual(contrast.recommend([(240, 240, 240)] * 100, (240, 240, 240), (220, 220, 220), 70), 70)

    def test_never_increases_transparency(self):
        for value in (0, 8, 44, 70, 100):
            self.assertLessEqual(contrast.recommend([(245, 240, 220)] * 100, (240, 240, 240), (25, 25, 25), value), value)

    @unittest.skipUnless(shutil.which("magick"), "ImageMagick is an Omarchy base package")
    def test_crop_uses_panel_position_and_preserves_acceptable_background(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "two areas.ppm"
            path.write_text("P3\n2 2\n255\n20 30 40 20 30 40\n245 240 230 245 240 230\n")
            source = path.as_uri() + "?cache=1"
            dark = contrast.sample_wallpaper(source, [200, 200], [0, 0, 200, 80])
            light = contrast.sample_wallpaper(source, [200, 200], [0, 120, 200, 80])
            self.assertEqual(contrast.recommend(dark, (240, 240, 240), (20, 20, 20), 70), 70)
            self.assertLess(contrast.recommend(light, (240, 240, 240), (20, 20, 20), 70), 70)
            with self.assertRaises(ValueError):
                contrast.sample_wallpaper(source, [200, 200], [300, 300, 20, 20])

    def test_invalid_sources_do_not_produce_a_default(self):
        for source in ("https://example.com/image.png", "file:///not-a-real-wallpaper"):
            with self.assertRaises((ValueError, OSError)):
                contrast.sample_wallpaper(source, [100, 100], [0, 0, 50, 50])

    def test_palette_guard_rejects_old_theme_colors_and_surface_overrides(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder) / "theme"
            directory.mkdir()
            (directory.parent / "theme.name").write_text("latte")
            (directory / "colors.toml").write_text('foreground = "#4c4f69"\nbackground = "#eff1f5"\n')
            state = {"directory": str(directory), "theme": "latte", "foreground": "#dcd7ba",
                     "background": "#1f1f28", "shell": {}}
            self.assertFalse(contrast.palette_matches(state))
            state.update(foreground="#4C4F69", background="#EFF1F5")
            self.assertTrue(contrast.palette_matches(state))
            (directory / "shell.toml").write_text('''[popups]
text = "#4c4f69" # new role
background-alpha = 1.0
[controls]
normal-border = foreground
normal-border-width = 1 2
''')
            self.assertFalse(contrast.palette_matches(state))
            state["shell"] = {"popups.text": "#4c4f69", "popups.background-alpha": "1.0",
                              "controls.normal-border": "foreground", "controls.normal-border-width": "1 2"}
            self.assertTrue(contrast.palette_matches(state))
            state["theme"] = "previous"
            self.assertFalse(contrast.palette_matches(state))


if __name__ == "__main__":
    unittest.main()
