"""Real local Git updates and atomic swaps; no network or desktop access."""
import importlib.util
import io
import json
import multiprocessing
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("windowpeek_update", ROOT / "update.py")
updates = importlib.util.module_from_spec(spec)
spec.loader.exec_module(updates)


class LocalUpdater(updates.Updater):
    def __init__(self, home, state, upstream):
        super().__init__(home, state, config=Path(home) / ".config")
        self.upstream = upstream
        self.requests = 0
        self.approval_requests = 0
        self.reloads = 0
        self.release = {"id": 11, "tag_name": "v0.0.2", "draft": False,
                        "prerelease": False, "immutable": True}
        self.catalog = {"stateSchemaVersion": 2, "plugins": []}

    def latest(self):
        self.requests += 1
        return self.release

    def git(self, directory, *args):
        if args and args[0] in ("fetch", "ls-remote"):
            args = tuple(str(self.upstream) if part == updates.REPOSITORY else part for part in args)
        return super().git(directory, "-c", "protocol.file.allow=always", *args)

    def approval(self):
        self.approval_requests += 1
        return updates.approved_commit(self.catalog)

    def validate(self, directory):
        if shutil.which("omarchy"):
            super().validate(directory)
        else:
            # CI has no Omarchy installation. The native run above uses its CLI.
            manifest = json.loads((directory / "manifest.json").read_text())
            if not all((directory / item).is_file() for item in manifest["entryPoints"].values()):
                raise ValueError("missing entry point")

    def reload(self):
        self.reloads += 1


class UpdatesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="windowpeek-updates-test-")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.remote = self.base / "upstream"
        self.remote.mkdir()
        self.worker = LocalUpdater(self.base / "home", self.base / "state", self.remote)
        self.worker.git(self.remote, "init", "-q")
        self.write_release("0.0.1")
        self.worker.plugin.parent.mkdir(parents=True)
        self.worker.command("git", "clone", "-q", str(self.remote), str(self.worker.plugin))
        self.worker.command("git", "-C", str(self.worker.plugin), "remote", "set-url", "origin", updates.REPOSITORY)
        self.original = self.worker.git(self.worker.plugin, "rev-parse", "HEAD")
        self.worker.state.mkdir(parents=True)
        self.prefs = self.worker.state / "preferences.json"
        self.prefs.write_text(json.dumps({"version": 1, "settings": {
            "autoUpdates": True, "language": "pl", "hintsMode": "auto", "hintsUsed": 61,
            "accentColor": "#EF98F5"}}))
        self.saved = self.prefs.read_bytes()
        self.write_release("0.0.2")
        self.target = self.worker.git(self.remote, "rev-parse", "HEAD")
        self.entry = {"id": updates.PLUGIN_ID, "repo": updates.REPOSITORY,
                      "sourceType": "community", "repositoryLayout": "root-plugin",
                      "manifestPath": "manifest.json", "installAvailable": True,
                      "verificationSnapshotStatus": "verified",
                      "listingValidatedCommit": self.target, "verificationCommit": self.target}
        self.worker.catalog["plugins"] = [self.entry]

    def write_release(self, value):
        manifest = {"schemaVersion": 1, "id": updates.PLUGIN_ID, "name": "WindowPeek", "author": "Sarr",
                    "version": value, "kinds": ["bar-widget"], "entryPoints": {"barWidget": "Widget.qml"}}
        (self.remote / "manifest.json").write_text(json.dumps(manifest))
        (self.remote / "Widget.qml").write_text('import QtQuick\nItem { property string release: "' + value + '" }\n')
        self.commit(self.remote)
        self.worker.git(self.remote, "tag", "v" + value)

    def commit(self, path):
        self.worker.git(path, "add", ".")
        self.worker.git(path, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "Fixture")

    def assert_unchanged(self):
        self.assertEqual(self.worker.git(self.worker.plugin, "rev-parse", "HEAD"), self.original)
        self.assertEqual(self.prefs.read_bytes(), self.saved)
        self.assertFalse(list(self.worker.plugin.parent.parent.glob(".windowpeek-update-*")))

    def test_stable_release_swaps_whole_tree_and_keeps_preferences(self):
        inode = self.worker.plugin.stat().st_ino
        self.assertEqual(self.worker.run(now=1000), "updated")
        self.assertNotEqual(self.worker.plugin.stat().st_ino, inode)
        self.assertEqual(json.loads((self.worker.plugin / "manifest.json").read_text())["version"], "0.0.2")
        self.assertEqual(self.worker.git(self.worker.plugin, "status", "--porcelain"), "")
        self.assertEqual(self.prefs.read_bytes(), self.saved)
        self.assertEqual(self.worker.reloads, 1)
        self.assertEqual(self.worker.git(self.worker.plugin, "rev-parse", "HEAD"), self.target)
        self.assertEqual(self.worker.git(self.worker.plugin, "remote", "get-url", "origin"), updates.REPOSITORY)
        self.assertEqual(self.worker.approval_requests, 2)
        self.assertFalse(list(self.worker.plugin.parent.parent.glob(".windowpeek-update-*")))

    def test_six_hour_deadline_survives_new_processes(self):
        self.worker.release["tag_name"] = "v0.0.1"
        self.assertEqual(self.worker.run(now=1000), "current")
        fresh = LocalUpdater(self.worker.home, self.worker.state.parent, self.remote)
        fresh.catalog = self.worker.catalog
        self.assertEqual(fresh.run(now=1001, startup=True), "not-due")
        self.assertEqual(fresh.requests, 0)
        self.assertEqual(fresh.run(now=1000 + updates.CHECK_INTERVAL - 1, startup=True), "not-due")
        self.assertEqual(fresh.run(now=1000 + updates.CHECK_INTERVAL, startup=True), "updated")
        self.assertEqual(fresh.requests, 2)

    def test_new_day_startup_checks_once_even_before_six_hours(self):
        last = int(time.mktime((2026, 9, 20, 23, 30, 0, 0, 0, -1)))
        now = int(time.mktime((2026, 9, 21, 0, 15, 0, 0, 0, -1)))
        self.worker.release["tag_name"] = "v0.0.1"
        self.assertEqual(self.worker.run(now=last), "current")
        self.assertEqual(self.worker.run(now=now), "not-due", "continuous runtime keeps the six-hour cadence")
        self.assertEqual(self.worker.run(now=now, startup=True), "current")
        fresh = LocalUpdater(self.worker.home, self.worker.state.parent, self.remote)
        self.assertEqual(fresh.run(now=now + 60, startup=True), "not-due")
        self.assertEqual(fresh.requests, 0)
        state = json.loads(self.worker.result.read_text())
        self.assertEqual(state["nextCheck"], now + updates.CHECK_INTERVAL)

    def test_old_daily_deadline_migrates_from_last_attempt(self):
        now = int(time.mktime((2026, 9, 21, 10, 0, 0, 0, 0, -1)))
        self.worker.result.write_text(json.dumps({"lastCheck": now, "nextCheck": now + 86400}))
        self.worker.release["tag_name"] = "v0.0.1"
        self.assertEqual(self.worker.run(now=now + 60, startup=True), "not-due")
        self.assertEqual(self.worker.requests, 0)
        self.assertEqual(self.worker.run(now=now + updates.CHECK_INTERVAL), "current")
        self.assertEqual(self.worker.requests, 1)

    def test_disabled_survives_a_new_worker(self):
        data = json.loads(self.prefs.read_text())
        data["settings"]["autoUpdates"] = False
        self.prefs.write_text(json.dumps(data))
        fresh = LocalUpdater(self.worker.home, self.worker.state.parent, self.remote)
        self.assertEqual(fresh.run(now=1000), "disabled")
        self.assertEqual(fresh.requests, 0)
        self.assertFalse(fresh.result.exists())

    def test_first_start_defaults_to_enabled(self):
        data = json.loads(self.prefs.read_text())
        del data["settings"]["autoUpdates"]
        self.prefs.write_text(json.dumps(data))
        self.assertTrue(self.worker.enabled())

    def test_invalid_preferences_never_start_network(self):
        for raw in ('bad json', '{"version":1,"settings":[]}', '{"version":2,"settings":{}}',
                    '{"version":true,"settings":{}}', '{"version":1,"settings":{"autoUpdates":"true"}}',
                    '{"version":1,"settings":{"autoUpdates":1}}', '{"version":1,"settings":{"autoUpdates":null}}'):
            with self.subTest(raw=raw):
                self.prefs.write_text(raw)
                self.assertEqual(self.worker.run(now=1000), "disabled")
                self.assertEqual(self.worker.requests, 0)

    def test_lock_prevents_concurrent_updates(self):
        with (self.worker.state / "updates.lock").open("w") as lock:
            updates.fcntl.flock(lock, updates.fcntl.LOCK_EX | updates.fcntl.LOCK_NB)
            self.assertEqual(self.worker.run(now=1000), "busy")
            self.assertEqual(self.worker.requests, 0)

    def test_separate_workers_share_lock_and_persistent_deadline(self):
        context = multiprocessing.get_context("fork")
        entered, resume = context.Event(), context.Event()
        results = context.Queue()
        validate = self.worker.validate

        def pause(stage):
            validate(stage)
            entered.set()
            if not resume.wait(10):
                raise TimeoutError("test did not resume download")

        def run():
            self.worker.validate = pause
            results.put(self.worker.run(now=1000))

        process = context.Process(target=run)
        process.start()
        try:
            self.assertTrue(entered.wait(10), "first process reached download validation")
            fresh = LocalUpdater(self.worker.home, self.worker.state.parent, self.remote)
            fresh.catalog = self.worker.catalog
            self.assertEqual(fresh.run(now=1001), "busy")
            self.assertEqual(fresh.requests, 0)
            resume.set()
            process.join(10)
            self.assertEqual(process.exitcode, 0)
            self.assertEqual(results.get(timeout=1), "updated")
            self.assertEqual(fresh.run(now=1002), "not-due")
            self.assertEqual(fresh.requests, 0)
        finally:
            resume.set()
            if process.is_alive():
                process.terminate()
            process.join(5)
            results.close()

    def test_missing_or_unreadable_preferences_block_network(self):
        self.prefs.chmod(0)
        try:
            self.assertEqual(self.worker.run(now=1000), "disabled")
        finally:
            self.prefs.chmod(0o600)
        self.prefs.unlink()
        self.assertEqual(self.worker.run(now=1000), "disabled")
        self.assertEqual(self.worker.requests, 0)
        self.assertFalse(self.worker.result.exists())

    def test_unwritable_schedule_blocks_network_and_can_be_retried(self):
        self.worker.state.chmod(0o500)
        try:
            with self.assertRaises(OSError):
                self.worker.run(now=1000)
            self.assertEqual(self.worker.requests, 0)
            self.assert_unchanged()
        finally:
            self.worker.state.chmod(0o700)
        self.assertEqual(self.worker.run(now=1000), "updated")

    def test_corrupt_and_future_schedule_do_not_block_checks_forever(self):
        self.worker.release["tag_name"] = "v0.0.1"
        for raw in ("broken", '{"nextCheck":true}', '{"nextCheck":999999999999}'):
            with self.subTest(raw=raw):
                self.worker.result.write_text(raw)
                self.assertEqual(self.worker.run(now=1000), "current")
                self.assertEqual(json.loads(self.worker.result.read_text())["nextCheck"], 1000 + updates.CHECK_INTERVAL)

    def test_offline_keeps_old_version_and_waits_six_hours(self):
        with patch.object(self.worker, "latest", side_effect=OSError("offline")) as latest:
            self.assertEqual(self.worker.run(now=1000), "failed")
            self.assertEqual(self.worker.run(now=1001, startup=True), "not-due")
            self.assertEqual(self.worker.run(now=1000 + updates.CHECK_INTERVAL), "failed")
            self.assertEqual(latest.call_count, 2)
        self.assert_unchanged()

    def test_draft_prerelease_bad_tags_and_malformed_responses_are_rejected(self):
        for release in ([], None, {}, {"draft": True}, {"prerelease": True},
                        {"draft": False, "prerelease": False, "tag_name": "v0.0.2-beta"},
                        {"draft": False, "prerelease": False, "tag_name": "v0.0.2;touch /tmp/x"}):
            with self.subTest(release=release):
                self.worker.release = release
                self.worker.result.unlink(missing_ok=True)
                self.assertEqual(self.worker.run(now=1000), "failed")
                self.assert_unchanged()

    def test_modified_and_untracked_files_prevent_network(self):
        (self.worker.plugin / "local.txt").write_text("user file")
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual(self.worker.requests, 0)
        self.assert_unchanged()

    def test_custom_origin_is_not_replaced(self):
        self.worker.command("git", "-C", str(self.worker.plugin), "remote", "set-url", "origin", "https://example.invalid/fork")
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual(self.worker.requests, 0)
        self.assert_unchanged()

    def test_development_symlink_is_skipped(self):
        real = self.base / "development"
        self.worker.plugin.rename(real)
        self.worker.plugin.symlink_to(real, target_is_directory=True)
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual(self.worker.requests, 0)
        self.assert_unchanged()

    def test_non_git_installation_is_skipped(self):
        (self.worker.plugin / ".git").rename(self.base / "saved-git")
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual(self.worker.requests, 0)
        self.assertEqual((self.worker.plugin / "manifest.json").read_bytes(),
                         self.worker.command("git", "--git-dir", str(self.base / "saved-git"),
                                             "show", "HEAD:manifest.json").encode())

    def test_local_commit_is_not_discarded(self):
        (self.worker.plugin / "local.txt").write_text("local feature")
        self.commit(self.worker.plugin)
        self.original = self.worker.git(self.worker.plugin, "rev-parse", "HEAD")
        self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_validation_failure_does_not_change_installed_tree(self):
        with patch.object(self.worker, "validate", side_effect=ValueError("invalid manifest")):
            self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_release_version_must_match_manifest(self):
        self.worker.git(self.remote, "tag", "v0.0.3")
        self.worker.release["tag_name"] = "v0.0.3"
        self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_failed_atomic_swap_leaves_original_in_place(self):
        with patch.object(updates, "exchange", side_effect=OSError("no space")):
            self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_disabling_while_downloading_prevents_install(self):
        def disable(stage):
            data = json.loads(self.prefs.read_text())
            data["settings"]["autoUpdates"] = False
            self.prefs.write_text(json.dumps(data))
        with patch.object(self.worker, "validate", side_effect=disable):
            self.assertEqual(self.worker.run(now=1000), "disabled")
        self.saved = self.prefs.read_bytes()
        self.assert_unchanged()

    def test_edit_while_downloading_is_preserved(self):
        with patch.object(self.worker, "validate", side_effect=lambda stage: (self.worker.plugin / "local.txt").write_text("editing")):
            self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual((self.worker.plugin / "local.txt").read_text(), "editing")
        self.assert_unchanged()

    def test_reload_failure_is_reported_without_reinstalling(self):
        with patch.object(self.worker, "reload", side_effect=OSError("shell closed")):
            self.assertEqual(self.worker.run(now=1000), "restart-pending")
        self.assertEqual(self.worker.run(now=1001), "not-due")
        self.assertEqual(json.loads((self.worker.plugin / "manifest.json").read_text())["version"], "0.0.2")

    def test_state_is_private(self):
        self.worker.release["tag_name"] = "v0.0.1"
        self.worker.run(now=1000)
        self.assertEqual(self.worker.result.stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.worker.state / "updates.lock").stat().st_mode & 0o777, 0o600)

    def test_mutable_release_is_never_downloaded(self):
        for value in (False, None, "true", 1):
            with self.subTest(immutable=value):
                self.worker.release["immutable"] = value
                self.worker.result.unlink(missing_ok=True)
                self.assertEqual(self.worker.run(now=1000), "unverified")
                self.assertEqual(self.worker.approval_requests, 0)
                self.assert_unchanged()

    def test_current_or_older_release_does_not_download_catalog(self):
        for tag in ("v0.0.1", "v0.0.0"):
            self.worker.release.update(tag_name=tag, immutable=False)
            self.worker.result.unlink(missing_ok=True)
            self.assertEqual(self.worker.run(now=1000), "current")
            self.assertEqual(self.worker.approval_requests, 0)
            self.assert_unchanged()

    def test_unlisted_unverified_or_wrong_repository_never_installs(self):
        variants = [[], [self.entry, self.entry]]
        for field, value in (("repo", "https://github.com/other/WindowPeek"),
                             ("sourceType", "official"), ("builtIn", True), ("placeholder", True),
                             ("repositoryLayout", "suite"), ("manifestPath", "sub/manifest.json"),
                             ("installAvailable", False), ("verificationSnapshotStatus", "unverified"),
                             ("verificationCommit", "0" * 40), ("listingValidatedCommit", "main")):
            variants.append([dict(self.entry, **{field: value})])
        for entries in variants:
            with self.subTest(entries=entries):
                self.worker.catalog["plugins"] = entries
                self.worker.result.unlink(missing_ok=True)
                self.assertEqual(self.worker.run(now=1000), "unverified")
                self.assert_unchanged()

    def test_unknown_catalog_schema_fails_closed(self):
        for catalog in (None, [], {}, {"stateSchemaVersion": 3, "plugins": [self.entry]},
                        {"stateSchemaVersion": 2, "plugins": {}}):
            self.worker.catalog = catalog
            self.worker.result.unlink(missing_ok=True)
            self.assertEqual(self.worker.run(now=1000), "failed")
            self.assert_unchanged()

    def test_unreviewed_head_does_not_override_approved_release(self):
        (self.remote / "unreviewed.txt").write_text("future work")
        self.commit(self.remote)
        self.entry.update(verificationStatus="unverified", verificationCoverage="update-unverified",
                          upstreamObservedCommit=self.worker.git(self.remote, "rev-parse", "HEAD"))
        self.assertEqual(self.worker.run(now=1000), "updated")
        self.assertFalse((self.worker.plugin / "unreviewed.txt").exists())
        self.assertEqual(self.worker.git(self.worker.plugin, "rev-parse", "HEAD"), self.target)

    def test_moved_tag_cannot_replace_reviewed_code_even_with_same_version(self):
        (self.remote / "Widget.qml").write_text("unreviewed replacement")
        self.commit(self.remote)
        self.worker.git(self.remote, "tag", "-f", "v0.0.2")
        with patch.object(self.worker, "validate") as validate:
            self.assertEqual(self.worker.run(now=1000), "unverified")
            validate.assert_not_called()
        self.assert_unchanged()

    def test_tag_changed_after_fetch_is_rejected(self):
        def move_tag(stage):
            self.worker.git(self.remote, "tag", "-f", "v0.0.2", self.original)
        with patch.object(self.worker, "validate", side_effect=move_tag):
            self.assertEqual(self.worker.run(now=1000), "unverified")
        self.assert_unchanged()

    def test_annotated_release_tag_resolves_to_reviewed_commit(self):
        self.worker.git(self.remote, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                        "tag", "-fa", "v0.0.2", "-m", "Release")
        self.assertEqual(self.worker.run(now=1000), "updated")

    def test_revoked_approval_during_download_preserves_old_install(self):
        def revoke(stage):
            self.entry["verificationSnapshotStatus"] = "unverified"
        with patch.object(self.worker, "validate", side_effect=revoke):
            self.assertEqual(self.worker.run(now=1000), "unverified")
        self.assert_unchanged()

    def test_new_approved_snapshot_during_download_requires_a_new_check(self):
        def replace(stage):
            self.entry.update(listingValidatedCommit="a" * 40, verificationCommit="a" * 40)
        with patch.object(self.worker, "validate", side_effect=replace):
            self.assertEqual(self.worker.run(now=1000), "unverified")
        self.assert_unchanged()

    def test_release_changed_or_withdrawn_during_download_does_not_install(self):
        for change in ({"id": 99}, {"tag_name": "v0.0.3"}, {"immutable": False},
                       {"draft": True}, {"prerelease": True}):
            with self.subTest(change=change):
                self.worker.result.unlink(missing_ok=True)
                confirmed = dict(self.worker.release, **change)
                with patch.object(self.worker, "latest", side_effect=[self.worker.release, confirmed]):
                    self.assertIn(self.worker.run(now=1000), ("unverified", "failed"))
                self.assert_unchanged()

    def test_final_authority_failure_never_uses_cached_approval(self):
        with patch.object(self.worker, "approval", side_effect=[self.target, OSError("offline")]):
            self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_staged_tampering_is_detected(self):
        def corrupt(stage):
            (stage / "Widget.qml").write_text("changed after validation")
        with patch.object(self.worker, "validate", side_effect=corrupt):
            self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_hidden_local_modifications_are_preserved(self):
        for flag in ("--assume-unchanged", "--skip-worktree"):
            with self.subTest(flag=flag):
                self.worker.git(self.worker.plugin, "update-index", flag, "Widget.qml")
                (self.worker.plugin / "Widget.qml").write_text("user modification")
                self.worker.result.unlink(missing_ok=True)
                self.assertEqual(self.worker.run(now=1000), "local-changes")
                self.assertEqual(self.worker.requests, 0)
                self.assertEqual((self.worker.plugin / "Widget.qml").read_text(), "user modification")
                self.assert_unchanged()

    def test_symlink_release_never_reaches_validation(self):
        (self.remote / "external").symlink_to(self.prefs)
        self.commit(self.remote)
        target = self.worker.git(self.remote, "rev-parse", "HEAD")
        self.entry.update(listingValidatedCommit=target, verificationCommit=target)
        self.worker.git(self.remote, "tag", "-f", "v0.0.2")
        with patch.object(self.worker, "validate") as validate:
            self.assertEqual(self.worker.run(now=1000), "failed")
            validate.assert_not_called()
        self.assert_unchanged()

    def test_submodule_release_never_reaches_validation(self):
        self.worker.git(self.remote, "update-index", "--add", "--cacheinfo", "160000", self.target, "dependency")
        self.worker.git(self.remote, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                        "commit", "-qm", "Gitlink fixture")
        target = self.worker.git(self.remote, "rev-parse", "HEAD")
        self.entry.update(listingValidatedCommit=target, verificationCommit=target)
        self.worker.git(self.remote, "tag", "-f", "v0.0.2")
        with patch.object(self.worker, "validate") as validate:
            self.assertEqual(self.worker.run(now=1000), "failed")
            validate.assert_not_called()
        self.assert_unchanged()

    def test_checkout_byte_transformation_is_rejected(self):
        # A clean git diff is insufficient: eol=crlf changes checkout bytes.
        (self.remote / ".gitattributes").write_text("Widget.qml text eol=crlf\n")
        self.commit(self.remote)
        target = self.worker.git(self.remote, "rev-parse", "HEAD")
        self.entry.update(listingValidatedCommit=target, verificationCommit=target)
        self.worker.git(self.remote, "tag", "-f", "v0.0.2")
        self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_installed_checkout_conversion_is_preserved_before_and_during_download(self):
        # The index and git status consider CRLF and LF equivalent with this attribute.
        attributes = self.worker.plugin / ".git/info/attributes"
        path = self.worker.plugin / "Widget.qml"
        original = path.read_bytes()
        transformed = original.replace(b"\n", b"\r\n")
        def convert():
            attributes.write_text("Widget.qml text eol=crlf\n")
            path.unlink()
            self.worker.git(self.worker.plugin, "checkout", "--", "Widget.qml")
        convert()
        self.assertEqual(self.worker.git(self.worker.plugin, "status", "--porcelain"), "")
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual(self.worker.requests, 0)
        self.assertEqual(path.read_bytes(), transformed)
        attributes.unlink()
        path.unlink()
        self.worker.git(self.worker.plugin, "checkout", "--", "Widget.qml")
        self.worker.result.unlink()
        with patch.object(self.worker, "validate", side_effect=lambda stage: convert()):
            self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual(path.read_bytes(), transformed)
        self.assert_unchanged()

    def test_executable_mode_is_checked_even_when_git_ignores_it(self):
        self.worker.git(self.worker.plugin, "config", "core.fileMode", "false")
        (self.worker.plugin / "Widget.qml").chmod(0o755)
        self.assertEqual(self.worker.git(self.worker.plugin, "status", "--porcelain"), "")
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertEqual(self.worker.requests, 0)
        self.assert_unchanged()

    def test_executable_blob_requires_owner_execute_permission(self):
        (self.remote / "Widget.qml").chmod(0o755)
        self.commit(self.remote)
        target = self.worker.git(self.remote, "rev-parse", "HEAD")
        self.entry.update(listingValidatedCommit=target, verificationCommit=target)
        self.worker.git(self.remote, "tag", "-f", "v0.0.2")
        def change_mode(stage):
            self.worker.git(stage, "config", "core.fileMode", "false")
            (stage / "Widget.qml").chmod(0o654)
        with patch.object(self.worker, "validate", side_effect=change_mode):
            self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_local_filters_and_config_includes_are_not_executed(self):
        marker = self.base / "filter-ran"
        (self.worker.plugin / ".git/info/attributes").write_text("Widget.qml filter=probe\n")
        self.worker.git(self.worker.plugin, "config", "filter.probe.clean", "touch '" + str(marker) + "'; cat")
        # Force git status to inspect the file instead of using the cached stat.
        (self.worker.plugin / "Widget.qml").touch()
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertFalse(marker.exists())
        self.worker.git(self.worker.plugin, "config", "--remove-section", "filter.probe")
        self.worker.result.unlink()
        included = self.base / "included-config"
        included.write_text('[filter "probe"]\nclean = touch "' + str(marker) + '"; cat\n')
        self.worker.git(self.worker.plugin, "config", "include.path", str(included))
        self.assertEqual(self.worker.run(now=1000), "local-changes")
        self.assertFalse(marker.exists())
        self.assertEqual(self.worker.requests, 0)

    def test_local_hooks_and_template_are_not_executed_or_copied(self):
        marker = self.base / "hook-ran"
        hook = self.worker.plugin / ".git/hooks/post-checkout"
        hook.write_text("#!/bin/sh\ntouch '" + str(marker) + "'\n")
        hook.chmod(0o700)
        with patch.dict(os.environ, {"GIT_TEMPLATE_DIR": str(self.worker.plugin / ".git")}):
            self.assertEqual(self.worker.run(now=1000), "updated")
        self.assertFalse(marker.exists())
        self.assertFalse((self.worker.plugin / ".git/hooks/post-checkout").exists())

    def test_git_environment_cannot_inject_a_different_directory_or_config(self):
        with patch.dict(os.environ, {"GIT_DIR": str(self.remote / ".git"),
                                    "GIT_WORK_TREE": str(self.remote), "GIT_CONFIG_COUNT": "1",
                                    "GIT_CONFIG_KEY_0": "core.hooksPath", "GIT_CONFIG_VALUE_0": "/bogus"}):
            self.assertEqual(self.worker.run(now=1000), "updated")
        self.assertEqual(self.worker.git(self.worker.plugin, "rev-parse", "HEAD"), self.target)

    def test_timeout_stops_command_children_before_cleanup(self):
        marker = self.base / "child-finished"
        child = "import time; from pathlib import Path; time.sleep(0.4); Path(" + repr(str(marker)) + ").touch()"
        parent = "import subprocess,sys,time; subprocess.Popen([sys.executable, '-c', " + repr(child) + "]); time.sleep(10)"
        with self.assertRaises(subprocess.TimeoutExpired):
            self.worker.command(sys.executable, "-c", parent, timeout=0.15)
        time.sleep(0.4)
        self.assertFalse(marker.exists())

    def test_staged_change_during_final_network_check_is_rejected(self):
        calls = 0
        def approval():
            nonlocal calls
            calls += 1
            if calls == 2:
                stage = next(self.worker.plugin.parent.parent.glob(".windowpeek-update-*/plugin"))
                (stage / "Widget.qml").write_text("modified during final check")
            return self.target
        with patch.object(self.worker, "approval", side_effect=approval):
            self.assertEqual(self.worker.run(now=1000), "failed")
        self.assert_unchanged()

    def test_second_update_installs_the_complete_project_and_keeps_preferences(self):
        self.assertEqual(self.worker.run(now=1000), "updated")
        for name in [str(p.relative_to(ROOT)) for p in ROOT.rglob("*")
                     if p.is_file() and not any(part in (".git", ".reference", "dist", "__pycache__")
                                                for part in p.relative_to(ROOT).parts)
                     and p.name not in ("AGENTS.md", "HANDOFF.md", "NEW_CHAT.txt")]:
            if not name:
                continue
            source, destination = ROOT / name, self.remote / name
            if source.is_file():
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, destination)
        self.commit(self.remote)
        target = self.worker.git(self.remote, "rev-parse", "HEAD")
        manifest = json.loads((self.remote / "manifest.json").read_text())
        tag = "v" + manifest["version"]
        self.worker.git(self.remote, "tag", tag)
        self.worker.release.update(id=12, tag_name=tag)
        self.entry.update(listingValidatedCommit=target, verificationCommit=target)
        self.assertEqual(self.worker.run(now=1000 + updates.CHECK_INTERVAL), "updated")
        self.assertEqual(self.worker.git(self.worker.plugin, "rev-parse", "HEAD"), target)
        for name in ("update.py", "Updates.qml", "manifest.json", "preview.png", "vendor/omarchy/LICENSE"):
            self.assertEqual((self.worker.plugin / name).read_bytes(), (ROOT / name).read_bytes())
        self.assertEqual(self.prefs.read_bytes(), self.saved)


class MetadataTest(unittest.TestCase):
    def test_plugin_identity_and_authorities_are_windowpeek_only(self):
        manifest = json.loads((ROOT / "manifest.json").read_text())
        source = json.loads((ROOT / "release.json").read_text())
        self.assertEqual(manifest["id"], updates.PLUGIN_ID)
        self.assertEqual(source, {"repository": updates.REPOSITORY,
                                  "latestRelease": updates.RELEASE_URL, "catalog": updates.CATALOG_URL})
        self.assertEqual(manifest["author"], "Sarr")

    def test_metadata_rejects_non_https_and_embedded_credentials(self):
        for url in ("http://example.invalid", "file:///tmp/catalog.json", "https://user:pass@example.invalid"):
            with self.subTest(url=url), patch("urllib.request.OpenerDirector.open") as request:
                with self.assertRaises(ValueError):
                    updates.read_json(url, 100)
                request.assert_not_called()

    def test_metadata_size_and_json_are_checked(self):
        for raw in (b"x" * 17, b"not json"):
            response = io.BytesIO(raw)
            response.status = 200
            response.geturl = lambda: updates.RELEASE_URL
            with patch("urllib.request.OpenerDirector.open", return_value=response):
                with self.assertRaises(ValueError):
                    updates.read_json(updates.RELEASE_URL, 16)

    def test_metadata_requests_have_no_auth_and_require_exact_source(self):
        response = io.BytesIO(b'{"ok":true}')
        response.status = 200
        response.geturl = lambda: updates.RELEASE_URL
        with patch("urllib.request.OpenerDirector.open", return_value=response) as request:
            self.assertEqual(updates.read_json(updates.RELEASE_URL, 100), {"ok": True})
        self.assertFalse(request.call_args.args[0].has_header("Authorization"))
        self.assertEqual(request.call_args.args[0].get_header("Cache-control"), "no-cache")

    def test_redirects_are_rejected(self):
        handler = updates.NoRedirect()
        self.assertIsNone(handler.redirect_request(None, None, 302, "Found", {}, "http://example.invalid"))
        response = io.BytesIO(b"{}")
        response.status = 200
        response.geturl = lambda: "https://example.invalid/catalog.json"
        with patch("urllib.request.OpenerDirector.open", return_value=response):
            with self.assertRaises(ValueError):
                updates.read_json(updates.CATALOG_URL, 100)


if __name__ == "__main__":
    unittest.main()
