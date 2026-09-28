"""Manual discovery is read-only; only a deliberate terminal action may update."""
import fcntl
import json
import os
import subprocess
import unittest
from unittest.mock import patch
import test_updates as fixtures

updates = fixtures.updates


class ManualUpdatesTest(unittest.TestCase):
    setUp = fixtures.UpdatesTest.setUp
    write_release = fixtures.UpdatesTest.write_release
    commit = fixtures.UpdatesTest.commit
    assert_unchanged = fixtures.UpdatesTest.assert_unchanged

    def manual(self):
        worker = updates.ManualUpdates(self.worker.home, self.worker.state.parent)
        self.requests = []
        def metadata(url, limit=0):
            self.requests.append(url)
            if url == updates.UPSTREAM_URL:
                return {"sha": self.target}
            if "/compare/" in url:
                return {"status": "ahead"}
            if url.endswith("/manifest.json"):
                return json.loads((self.remote / "manifest.json").read_text())
            if url == updates.CATALOG_URL:
                return self.worker.catalog
            raise AssertionError(url)
        worker.metadata = metadata
        return worker

    def test_discovery_reads_metadata_without_fetch_install_or_preferences_change(self):
        worker = self.manual()
        self.assertEqual(worker.check(now=1000), "available")
        result = json.loads(worker.result.read_text())
        self.assertEqual(result["commit"], self.target)
        self.assertEqual(result["version"], "0.0.2")
        self.assertEqual(result["verification"], "verified")
        self.assertEqual(len(self.requests), 4)
        self.assertFalse((worker.plugin / ".git/FETCH_HEAD").exists())
        self.assert_unchanged()
        self.assertEqual(worker.check(now=1001), "not-due")
        self.assertEqual(len(self.requests), 4)
        self.assertEqual(worker.check(force=True, now=1002), "available")

    def test_unverified_and_unreachable_catalog_are_distinct(self):
        worker = self.manual()
        self.entry["listingValidatedCommit"] = self.original
        self.entry["verificationCommit"] = self.original
        worker.check(force=True, now=1000)
        self.assertEqual(json.loads(worker.result.read_text())["verification"], "unverified")
        original = worker.metadata
        def metadata(url, limit=0):
            if url == updates.CATALOG_URL:
                raise OSError("offline")
            return original(url, limit)
        worker.metadata = metadata
        worker.check(force=True, now=1001)
        self.assertEqual(json.loads(worker.result.read_text())["verification"], "unknown")
        self.assert_unchanged()

    def test_opt_out_blocks_scheduled_checks_but_manual_check_still_works(self):
        worker = self.manual()
        prefs = json.loads(self.prefs.read_text())
        prefs["settings"].update(autoUpdates=False, checkUpdates=False)
        self.prefs.write_text(json.dumps(prefs))
        self.assertEqual(worker.check(now=1000), "disabled")
        self.assertEqual(self.requests, [])
        self.assertEqual(worker.check(force=True, now=1001), "available")
        self.assertFalse(json.loads(self.prefs.read_text())["settings"]["checkUpdates"])

    def test_same_version_new_commit_is_available_but_no_downgrades(self):
        worker = self.manual()
        original = worker.metadata
        worker.metadata = lambda url, limit=0: ({"id": updates.PLUGIN_ID, "version": "0.0.1"}
            if url.endswith("/manifest.json") else original(url, limit))
        self.assertEqual(worker.check(force=True, now=1000), "available")
        worker.metadata = lambda url, limit=0: ({"id": updates.PLUGIN_ID, "version": "0.0.0"}
            if url.endswith("/manifest.json") else original(url, limit))
        self.assertEqual(worker.check(force=True, now=1001), "failed")
        self.assertNotIn("commit", json.loads(worker.result.read_text()))

    def test_current_ahead_diverged_and_invalid_remote(self):
        worker = self.manual()
        original = worker.metadata
        worker.metadata = lambda url, limit=0: {"sha": self.original}
        self.assertEqual(worker.check(force=True, now=1000), "current")
        for relation, expected in (("behind", "ahead"), ("diverged", "local-changes"), (None, "local-changes")):
            worker.metadata = lambda url, limit=0: {"status": relation} if "/compare/" in url else original(url, limit)
            self.assertEqual(worker.check(force=True, now=1000), expected)
        worker.metadata = lambda url, limit=0: {"sha": "$(untrusted)"}
        self.assertEqual(worker.check(force=True, now=1000), "failed")
        self.assert_unchanged()

    def test_edited_copy_cannot_launch_even_after_successful_discovery(self):
        worker = self.manual()
        self.assertEqual(worker.check(now=1000), "available")
        (worker.plugin / "Widget.qml").write_text("local edit")
        with patch.object(os, "isatty", return_value=True), patch.object(subprocess, "run") as command:
            self.assertEqual(worker.confirm_in_terminal(), 1)
            command.assert_not_called()
        self.assertEqual(worker.check(force=True, now=1001), "local-changes")
        self.assertEqual(json.loads(worker.result.read_text())["reason"], "local-copy")

    def test_terminal_required_and_native_command_keeps_confirmation_and_lock(self):
        worker = self.manual()
        with patch.object(os, "isatty", return_value=False), patch.object(subprocess, "run") as command:
            with self.assertRaises(ValueError):
                worker.confirm_in_terminal()
            command.assert_not_called()
        def native_command(args, check):
            self.assertEqual(args, ["omarchy", "plugin", "update", "sarr.windowpeek"])
            self.assertFalse(check)
            with (worker.state / "updates.lock").open("w") as lock:
                with self.assertRaises(BlockingIOError):
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return subprocess.CompletedProcess(args, 0)
        with patch.object(os, "isatty", return_value=True), patch.object(subprocess, "run", side_effect=native_command):
            self.assertEqual(worker.confirm_in_terminal(), 0)
        self.assert_unchanged()

    def test_busy_lock_blocks_both_discovery_and_terminal(self):
        worker = self.manual()
        with (worker.state / "updates.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(worker.check(force=True, now=1000), "busy")
            with patch.object(os, "isatty", return_value=True), patch.object(subprocess, "run") as command:
                self.assertEqual(worker.confirm_in_terminal(), 1)
                command.assert_not_called()
        self.assertEqual(self.requests, [])

    def test_custom_loaded_copy_cannot_update_a_different_standard_installation(self):
        worker = self.manual()
        worker.source = self.base / "custom-plugin"
        self.assertEqual(worker.check(force=True, now=1000), "local-changes")
        self.assertEqual(json.loads(worker.result.read_text())["reason"], "development")
        self.assertEqual(self.requests, [])
        with patch.object(os, "isatty", return_value=True), patch.object(subprocess, "run") as command:
            self.assertEqual(worker.confirm_in_terminal(), 1)
            command.assert_not_called()

    def test_development_link_refreshes_old_blocked_cache_without_network_or_install(self):
        worker = self.manual()
        checkout = self.base / "development"
        worker.plugin.rename(checkout)
        worker.plugin.symlink_to(checkout, target_is_directory=True)
        worker.result.write_text(json.dumps({"status":"local-changes", "lastCheck":1000, "nextCheck":22600}))
        self.assertEqual(worker.check(now=1001), "local-changes")
        self.assertEqual(json.loads(worker.result.read_text())["reason"], "development")
        self.assertEqual(self.requests, [])
        self.assertEqual(worker.check(now=1002), "not-due")
        self.assertEqual(worker.git(checkout, "rev-parse", "HEAD"), self.original)
        with patch.object(os, "isatty", return_value=True), patch.object(subprocess, "run") as command:
            self.assertEqual(worker.confirm_in_terminal(), 1)
            command.assert_not_called()

    def test_confirmed_update_refreshes_shell_but_cancel_or_failure_does_not(self):
        worker = self.manual()
        def install(args, check):
            worker.git(worker.plugin, "-c", "protocol.file.allow=always", "fetch", str(self.remote))
            worker.git(worker.plugin, "merge", "--ff-only", "FETCH_HEAD")
            return subprocess.CompletedProcess(args, 0)
        with patch.object(os, "isatty", return_value=True), patch.object(worker, "reload") as reload:
            for code in (0, 1):
                with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], code)):
                    self.assertEqual(worker.confirm_in_terminal(), code)
                    reload.assert_not_called()
            with patch.object(subprocess, "run", side_effect=install):
                self.assertEqual(worker.confirm_in_terminal(), 0)
            reload.assert_called_once()
            self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.target)
            self.assertEqual(json.loads(worker.result.read_text())["status"], "")


if __name__ == "__main__":
    unittest.main()
