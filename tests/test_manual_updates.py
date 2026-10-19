"""Read-only published-release discovery and exact-commit installation."""
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
            if url == updates.RELEASE_URL:
                return self.worker.release
            if url.endswith("/git/ref/tags/v0.0.2"):
                return {"ref": "refs/tags/v0.0.2", "object": {"type": "commit", "sha": self.target}}
            if "/compare/" in url:
                return {"status": "ahead"}
            if url.endswith("/manifest.json"):
                return json.loads((self.remote / "manifest.json").read_text())
            if url == updates.CATALOG_URL:
                return self.worker.catalog
            raise AssertionError(url)
        worker.metadata = metadata
        return worker

    def exact_worker(self):
        self.worker.git(self.remote, "branch", "-f", "main", self.target)
        worker = self.manual()
        original_git = worker.git
        def git(directory, *args):
            if args and args[0] in ("fetch", "ls-remote"):
                args = tuple(str(self.remote) if part == updates.REPOSITORY else part for part in args)
            return original_git(directory, "-c", "protocol.file.allow=always", *args)
        worker.git = git
        worker.validate = lambda stage: self.assertEqual(
            json.loads((stage / "manifest.json").read_text())["id"], updates.PLUGIN_ID)
        worker.reload = lambda: None
        return worker

    def test_discovery_reads_metadata_without_fetch_install_or_preferences_change(self):
        worker = self.manual()
        self.assertEqual(worker.check(now=1000), "available")
        result = json.loads(worker.result.read_text())
        self.assertEqual(result["commit"], self.target)
        self.assertEqual(result["version"], "0.0.2")
        self.assertEqual((result["releaseId"], result["releaseTag"]), (11, "v0.0.2"))
        self.assertEqual(result["verification"], "verified")
        self.assertEqual(len(self.requests), 5)
        self.assertFalse((worker.plugin / ".git/FETCH_HEAD").exists())
        self.assert_unchanged()
        self.assertEqual(worker.check(now=1001), "not-due")
        self.assertEqual(len(self.requests), 5)
        self.assertEqual(worker.check(force=True, now=1002), "available")

    def test_confirmation_installs_only_the_checked_commit(self):
        worker = self.exact_worker()
        self.assertEqual(worker.check(now=1000), "available")
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "updated")
        self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.target)
        self.assertEqual(self.prefs.read_bytes(), self.saved)
        self.assertFalse(list(worker.plugin.parent.parent.glob(".windowpeek-update-*")))

    def test_changed_or_revoked_offer_does_not_install(self):
        worker = self.exact_worker()
        self.assertEqual(worker.check(now=1000), "available")
        self.assertEqual(worker.install_exact("a" * 40, "0.0.2", "verified"), "stale")
        self.assert_unchanged()
        self.entry["listingValidatedCommit"] = self.original
        self.entry["verificationCommit"] = self.original
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "failed")
        self.assert_unchanged()
        self.assertEqual(json.loads(worker.result.read_text())["installError"], "failed")

    def test_explicit_amber_release_installs_the_checked_tag(self):
        worker = self.exact_worker()
        self.entry["listingValidatedCommit"] = self.original
        self.entry["verificationCommit"] = self.original
        self.assertEqual(worker.check(now=1000), "available")
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "unverified"), "updated")
        self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.target)

    def test_early_release_opt_out_blocks_install_until_same_commit_is_verified(self):
        worker = self.exact_worker()
        self.entry["listingValidatedCommit"] = self.original
        self.entry["verificationCommit"] = self.original
        self.assertEqual(worker.check(now=1000), "available")
        amber = json.loads(worker.result.read_text())
        prefs = json.loads(self.prefs.read_text())
        prefs["settings"]["includeUnverifiedUpdates"] = False
        self.prefs.write_text(json.dumps(prefs))
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "unverified"), "stale")
        self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.original)
        self.entry["listingValidatedCommit"] = self.target
        self.entry["verificationCommit"] = self.target
        self.assertEqual(worker.check(force=True, now=1001), "available")
        green = json.loads(worker.result.read_text())
        self.assertEqual(green["verification"], "verified")
        for key in ("commit", "version", "releaseId", "releaseTag"):
            self.assertEqual(green[key], amber[key])
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "updated")

    def test_opt_out_offers_older_verified_release_while_latest_is_early(self):
        worker = self.exact_worker()
        self.write_release("0.0.3")
        newest = worker.git(self.remote, "rev-parse", "HEAD")
        self.worker.release = {"id": 12, "tag_name": "v0.0.3", "draft": False,
                               "prerelease": False, "immutable": True}
        prefs = json.loads(self.prefs.read_text())
        prefs["settings"]["includeUnverifiedUpdates"] = False
        self.prefs.write_text(json.dumps(prefs))
        original_metadata = worker.metadata
        def metadata(url, limit=0):
            if url.endswith("/git/ref/tags/v0.0.3"):
                return {"ref": "refs/tags/v0.0.3", "object": {"type": "commit", "sha": newest}}
            if url.endswith("/releases/tags/v0.0.2"):
                return {"id": 11, "tag_name": "v0.0.2", "draft": False,
                        "prerelease": False, "immutable": True}
            if url.endswith("/" + self.target + "/manifest.json"):
                return json.loads(worker.git(self.remote, "show", self.target + ":manifest.json"))
            return original_metadata(url, limit)
        worker.metadata = metadata
        self.assertEqual(worker.check(now=1000), "available")
        result = json.loads(worker.result.read_text())
        self.assertEqual((result["version"], result["commit"], result["verification"]),
                         ("0.0.2", self.target, "verified"))
        self.assertTrue(result["catalogRelease"])
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "updated")
        self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.target)

    def test_disabling_early_releases_during_install_stops_exchange(self):
        worker = self.exact_worker()
        self.entry["listingValidatedCommit"] = self.original
        self.entry["verificationCommit"] = self.original
        self.assertEqual(worker.check(now=1000), "available")
        original_validate = worker.validate
        def change_preference(stage):
            original_validate(stage)
            prefs = json.loads(self.prefs.read_text())
            prefs["settings"]["includeUnverifiedUpdates"] = False
            self.prefs.write_text(json.dumps(prefs))
        worker.validate = change_preference
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "unverified"), "failed")
        self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.original)

    def test_tag_moving_after_confirmation_never_substitutes_a_commit(self):
        worker = self.exact_worker()
        self.assertEqual(worker.check(now=1000), "available")
        worker.git(self.remote, "tag", "-f", "v0.0.2", self.original)
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "failed")
        self.assert_unchanged()
        self.assertEqual(json.loads(worker.result.read_text())["installError"], "failed")

    def test_main_moving_does_not_change_an_immutable_release(self):
        worker = self.exact_worker()
        self.assertEqual(worker.check(now=1000), "available")
        worker.git(self.remote, "branch", "-f", "main", self.original)
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "updated")
        self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.target)

    def test_new_local_edit_blocks_exact_install_and_can_be_rechecked(self):
        worker = self.exact_worker()
        self.assertEqual(worker.check(now=1000), "available")
        original = (worker.plugin / "Widget.qml").read_bytes()
        (worker.plugin / "Widget.qml").write_text("local edit")
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "local-changes")
        self.assertEqual(json.loads(worker.result.read_text())["installError"], "local-changes")
        (worker.plugin / "Widget.qml").write_bytes(original)
        self.assertEqual(worker.check(force=True, now=1001), "available")
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "updated")

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

    def test_same_published_release_turns_green_after_catalog_approval(self):
        worker = self.manual()
        self.entry["listingValidatedCommit"] = self.original
        self.entry["verificationCommit"] = self.original
        self.assertEqual(worker.check(force=True, now=1000), "available")
        amber = json.loads(worker.result.read_text())
        self.assertEqual(amber["verification"], "unverified")
        self.entry["listingValidatedCommit"] = self.target
        self.entry["verificationCommit"] = self.target
        self.assertEqual(worker.check(force=True, now=1001), "available")
        green = json.loads(worker.result.read_text())
        self.assertEqual(green["verification"], "verified")
        for key in ("commit", "version", "releaseId", "releaseTag"):
            self.assertEqual(green[key], amber[key])
        self.assert_unchanged()

    def test_annotated_release_tag_resolves_and_installs_its_commit(self):
        worker = self.exact_worker()
        worker.git(self.remote, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                   "tag", "-f", "-a", "v0.0.2", "-m", "Fixture release")
        tag_sha = worker.git(self.remote, "rev-parse", "refs/tags/v0.0.2")
        original = worker.metadata
        def metadata(url, limit=0):
            if url.endswith("/git/ref/tags/v0.0.2"):
                return {"ref":"refs/tags/v0.0.2", "object":{"type":"tag", "sha":tag_sha}}
            if url.endswith("/git/tags/" + tag_sha):
                return {"tag":"v0.0.2", "object":{"type":"commit", "sha":self.target}}
            return original(url, limit)
        worker.metadata = metadata
        self.assertEqual(worker.check(now=1000), "available")
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "updated")
        self.assertEqual(worker.git(worker.plugin, "rev-parse", "HEAD"), self.target)

    def test_opt_out_blocks_scheduled_checks_but_manual_check_still_works(self):
        worker = self.manual()
        prefs = json.loads(self.prefs.read_text())
        prefs["settings"].update(autoUpdates=False, checkUpdates=False)
        self.prefs.write_text(json.dumps(prefs))
        self.assertEqual(worker.check(now=1000), "disabled")
        self.assertEqual(self.requests, [])
        self.assertEqual(worker.check(force=True, now=1001), "available")
        self.assertFalse(json.loads(self.prefs.read_text())["settings"]["checkUpdates"])

    def test_old_automatic_install_choice_does_not_block_notifications(self):
        worker = self.manual()
        prefs = json.loads(self.prefs.read_text())
        prefs["settings"].update(autoUpdates=False, checkUpdates=True)
        self.prefs.write_text(json.dumps(prefs))
        self.assertEqual(worker.check(now=1000), "available")
        self.assertEqual(json.loads(worker.result.read_text())["commit"], self.target)

    def test_release_manifest_must_match_the_published_tag(self):
        worker = self.manual()
        original = worker.metadata
        worker.metadata = lambda url, limit=0: ({"id": updates.PLUGIN_ID, "version": "0.0.1"}
            if url.endswith("/manifest.json") else original(url, limit))
        self.assertEqual(worker.check(force=True, now=1000), "failed")
        self.assertNotIn("commit", json.loads(worker.result.read_text()))

    def test_draft_prerelease_and_mutable_release_are_never_offered(self):
        worker = self.manual()
        for key in ("draft", "prerelease"):
            self.worker.release[key] = True
            self.assertEqual(worker.check(force=True, now=1000), "failed")
            self.worker.release[key] = False
        self.worker.release["immutable"] = False
        self.assertEqual(worker.check(force=True, now=1001), "failed")
        self.assert_unchanged()

    def test_current_ahead_diverged_and_invalid_release_ref(self):
        worker = self.manual()
        original = worker.metadata
        def current(url, limit=0):
            if url.endswith("/git/ref/tags/v0.0.2"):
                return {"ref":"refs/tags/v0.0.2", "object":{"type":"commit", "sha":self.original}}
            return original(url, limit)
        worker.metadata = current
        self.assertEqual(worker.check(force=True, now=1000), "current")
        for relation, expected in (("behind", "ahead"), ("diverged", "local-changes"), (None, "local-changes")):
            worker.metadata = lambda url, limit=0: {"status": relation} if "/compare/" in url else original(url, limit)
            self.assertEqual(worker.check(force=True, now=1000), expected)
        worker.metadata = lambda url, limit=0: ({"ref":"refs/tags/v0.0.2", "object":{"type":"commit", "sha":"$(untrusted)"}}
            if url.endswith("/git/ref/tags/v0.0.2") else original(url, limit))
        self.assertEqual(worker.check(force=True, now=1000), "failed")
        self.assert_unchanged()

    def test_latest_release_changing_during_install_aborts(self):
        worker = self.exact_worker()
        self.assertEqual(worker.check(now=1000), "available")
        worker.validate = lambda stage: self.worker.release.update(id=12)
        self.assertEqual(worker.install_exact(self.target, "0.0.2", "verified"), "failed")
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
