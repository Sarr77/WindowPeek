import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import install
import update


class InstallationTests(unittest.TestCase):
    def test_install_replace_remove_and_reinstall_preserve_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            profile = Path(directory)
            state = profile / "state/windowpeek"
            state.mkdir(parents=True)
            settings = state / "preferences.json"
            settings.write_text('{"version":1,"settings":{"hintsUsed":37,"language":"pl"}}')
            original = settings.read_bytes()
            target = install.install(ROOT, profile / "config")
            self.assertEqual(json.loads((target / "manifest.json").read_text())["id"], install.PLUGIN_ID)
            self.assertTrue((target / "vendor/omarchy/LICENSE").is_file())
            self.assertTrue((target / "vendor/omarchy/OmarchyLogo.qml").is_file())
            self.assertFalse((target / ".reference").exists())
            self.assertFalse((target / "HANDOFF.md").exists())
            install.install(ROOT, profile / "config")
            install.uninstall(profile / "config")
            self.assertFalse(target.exists())
            install.install(ROOT, profile / "config", link=True)
            self.assertTrue(target.is_symlink())
            install.uninstall(profile / "config")
            self.assertTrue((ROOT / "WindowModel.js").exists())
            self.assertEqual(settings.read_bytes(), original)

    def test_unrecognized_destination_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "omarchy/plugins" / install.PLUGIN_ID
            target.mkdir(parents=True)
            (target / "sentinel").write_text("keep")
            with self.assertRaises(ValueError):
                install.install(ROOT, directory)
            with self.assertRaises(ValueError):
                install.uninstall(directory)
            self.assertEqual((target / "sentinel").read_text(), "keep")

    def test_updater_without_saved_preferences_does_not_write_or_access_network(self):
        with tempfile.TemporaryDirectory() as directory:
            class OfflineUpdater(update.Updater):
                def latest(self):
                    raise AssertionError("Network must not be used")
            worker = OfflineUpdater(Path(directory) / "home", Path(directory) / "state")
            self.assertEqual(worker.run(), "disabled")
            self.assertFalse(worker.state.exists())

    def test_stable_versions_reject_drafts_and_invalid_tags(self):
        self.assertEqual(update.version("0.1.0"), (0, 1, 0))
        for value in ("01.0.0", "v1.0.0", "1.0.0-beta", "1.0", None):
            with self.assertRaises(ValueError):
                update.version(value)


if __name__ == "__main__":
    unittest.main()
