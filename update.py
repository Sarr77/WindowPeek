#!/usr/bin/env python3
"""Discover WindowPeek updates and install an explicitly approved exact commit.

Scheduled checks only read metadata. An installation starts only after a user
chooses the displayed commit in WindowPeek; the detached worker validates the
checkout and confirms the remote identity again before replacing the plugin.
"""
import ctypes
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import tempfile
import time
import urllib.request
import urllib.parse

PLUGIN_ID = "sarr.windowpeek"
REPOSITORY = "https://github.com/Sarr77/WindowPeek"
RELEASE_URL = "https://api.github.com/repos/Sarr77/WindowPeek/releases/latest"
RELEASE_TAG_URL = "https://api.github.com/repos/Sarr77/WindowPeek/releases/tags/"
CATALOG_URL = "https://plugins.omarchy.org/catalog.json"
CHECK_INTERVAL = 6 * 60 * 60


def timestamp(value):
    return value if type(value) in (int, float) and math.isfinite(value) and value > 0 else 0


def check_due(previous, now, startup=False):
    last = timestamp(previous.get("lastCheck"))
    if 0 < last <= now:
        # A startup on a new local calendar day can precede the regular deadline.
        if startup and time.localtime(last)[:3] != time.localtime(now)[:3]:
            return True
        return now >= last + CHECK_INTERVAL
    if startup:
        return True
    deadline = timestamp(previous.get("nextCheck"))
    return not now < deadline <= now + CHECK_INTERVAL


class UnverifiedUpdate(ValueError):
    """A release exists, but it is not eligible for automatic installation."""


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        # Neither trust authority may redirect the check to a different source.
        return None


def read_json(url, limit):
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.fragment:
        raise ValueError("metadata requires an HTTPS source")
    request = urllib.request.Request(url, headers={
        "Accept": "application/json", "Cache-Control": "no-cache",
        "User-Agent": "WindowPeek-Updater"})
    with urllib.request.build_opener(NoRedirect()).open(request, timeout=20) as response:
        if response.status != 200 or response.geturl() != url:
            raise ValueError("unexpected metadata response")
        raw = response.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("metadata response too large")
    return json.loads(raw)


def read_local_json(path, limit):
    """Never consume an unbounded or special local state file in a worker."""
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise ValueError("local metadata is not a bounded regular file")
        raw = bytearray()
        while len(raw) <= limit:
            block = os.read(descriptor, min(65536, limit + 1 - len(raw)))
            if not block:
                break
            raw.extend(block)
        if len(raw) > limit:
            raise ValueError("local metadata too large")
        return json.loads(raw)
    finally:
        os.close(descriptor)


def release_identity(release):
    if (not isinstance(release, dict) or release.get("draft") is not False
            or release.get("prerelease") is not False
            or type(release.get("id")) is not int or release["id"] <= 0):
        raise ValueError("release is not a published stable release")
    tag = release.get("tag_name", "")
    if not isinstance(tag, str) or not tag.startswith("v"):
        raise ValueError("invalid release tag")
    version(tag[1:])
    return release["id"], tag


def approved_commit(catalog):
    """Use the marketplace's canonical projection, never our own release's SHA.

    Snapshot verification remains valid when unrelated upstream HEAD changes.
    The marketplace resolves baseline policy, maintainer review and revocation;
    this consumer checks the exact repository, plugin and snapshot binding.
    """
    if (not isinstance(catalog, dict) or type(catalog.get("stateSchemaVersion")) is not int
            or catalog["stateSchemaVersion"] != 2 or not isinstance(catalog.get("plugins"), list)):
        raise ValueError("unsupported marketplace catalog")
    matches = [p for p in catalog["plugins"] if isinstance(p, dict) and p.get("id") == PLUGIN_ID]
    if len(matches) != 1:
        raise UnverifiedUpdate("marketplace listing missing or ambiguous")
    entry = matches[0]
    commit = entry.get("listingValidatedCommit", "")
    if (entry.get("repo") != REPOSITORY or entry.get("sourceType") != "community"
            or entry.get("builtIn") or entry.get("placeholder")
            or entry.get("repositoryLayout") != "root-plugin"
            or entry.get("manifestPath") != "manifest.json"
            or entry.get("installAvailable") is not True
            or entry.get("verificationSnapshotStatus") != "verified"
            or not isinstance(commit, str) or not re.fullmatch(r"[a-f0-9]{40}", commit)
            or entry.get("verificationCommit") != commit):
        raise UnverifiedUpdate("marketplace has no verified installable snapshot")
    return commit


def version(value):
    if not isinstance(value, str) or not re.fullmatch(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)", value):
        raise ValueError("not a stable version")
    return tuple(map(int, value.split(".")))


def atomic_json(path, value):
    fd, temporary = tempfile.mkstemp(prefix=".update-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def exchange(left, right):
    """One Linux rename exposes the complete validated tree, never half an update."""
    rename = getattr(ctypes.CDLL(None, use_errno=True), "renameat2", None)
    if rename is None:
        raise OSError("atomic directory exchange is unavailable")
    rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    if rename(-100, os.fsencode(left), -100, os.fsencode(right), 2):
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error))


class Updater:
    def __init__(self, home, state, config=None):
        self.home = Path(home)
        self.state = Path(state) / "windowpeek"
        config = Path(config) if config is not None else Path(os.environ.get("XDG_CONFIG_HOME") or self.home / ".config")
        self.plugin = config / "omarchy/plugins" / PLUGIN_ID
        self.result = self.state / "updates.json"

    def enabled(self):
        try:
            prefs = read_local_json(self.state / "preferences.json", 262144)
            return (type(prefs["version"]) is int and prefs["version"] == 1
                    and isinstance(prefs["settings"], dict)
                    and prefs["settings"].get("autoUpdates", True) is True)
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            return False

    def command(self, *args, timeout=60):
        # Do not inherit Git config injection, alternate objects or index paths.
        environment = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
        environment.update(GIT_TERMINAL_PROMPT="0", GIT_CONFIG_NOSYSTEM="1",
                           GIT_CONFIG_GLOBAL="/dev/null", GIT_NO_REPLACE_OBJECTS="1",
                           GIT_ATTR_NOSYSTEM="1")
        with subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, env=environment, start_new_session=True) as process:
            try:
                stdout, stderr = process.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                # Git's transport/pack children must stop before staging cleanup.
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                raise
            if process.returncode:
                raise subprocess.CalledProcessError(process.returncode, args, stdout, stderr)
            return stdout.strip()

    def git(self, directory, *args):
        # A fresh stage also avoids installed local filters, hooks and config.
        return self.command("git", "-c", "core.hooksPath=/dev/null", "-c", "credential.helper=",
                            "-c", "core.fsmonitor=false", "-c", "core.attributesFile=/dev/null",
                            "-c", "core.autocrlf=false", "-c", "http.followRedirects=false",
                            "-c", "protocol.allow=never", "-c", "protocol.https.allow=always",
                            "-C", str(directory), *args)

    def latest(self):
        return read_json(RELEASE_URL, 256 * 1024)

    def approval(self):
        # Only requested for a newer immutable release, not on every scheduled check.
        return approved_commit(read_json(CATALOG_URL, 32 * 1024 * 1024))

    def validate(self, directory):
        self.command("omarchy", "plugin", "validate", str(directory))

    def reload(self):
        # A rescan can retain old QML components and shared singletons.
        self.command("omarchy", "restart", "shell", timeout=15)

    def clean(self, directory=None):
        directory = self.plugin if directory is None else directory
        if self.git(directory, "status", "--porcelain", "--untracked-files=all", "--ignored"):
            return False
        # These index flags can conceal user modifications from git status.
        return all(item.startswith("H ") for item in
                   self.git(directory, "ls-files", "-v", "-z").split("\0") if item)

    def verify_tree(self, directory, commit):
        """Check raw installed bytes and executable modes against Git blob IDs.

        git status alone can hide checkout transformations such as CRLF or
        encoding conversion. No release-provided verification code is executed.
        """
        if not self.clean(directory):
            raise ValueError("staged checkout changed")
        for entry in self.git(directory, "ls-tree", "-rz", commit).split("\0"):
            if not entry:
                continue
            metadata, name = entry.split("\t", 1)
            mode, kind, expected = metadata.split()
            if mode not in ("100644", "100755") or kind != "blob":
                raise ValueError("release contains a symlink or submodule")
            path = directory / name
            # A regular leaf can still sit below a replaced symlink directory.
            for parent in path.parents:
                if parent == directory:
                    break
                if parent.is_symlink():
                    raise ValueError("checkout contains a symlink directory")
            info = path.lstat()
            if (not stat.S_ISREG(info.st_mode) or info.st_mode & 0o7000
                    or bool(info.st_mode & stat.S_IXUSR) != (mode == "100755")
                    or (mode == "100644" and info.st_mode & 0o111)):
                raise ValueError("release file type or mode mismatch")
            digest = hashlib.sha1(f"blob {info.st_size}\0".encode())
            with path.open("rb") as stream:
                while block := stream.read(128 * 1024):
                    digest.update(block)
            if digest.hexdigest() != expected:
                raise ValueError("release file integrity mismatch")

    def eligible(self):
        if self.plugin.is_symlink() or not (self.plugin / ".git").is_dir() or (self.plugin / ".git").is_symlink():
            return False
        metadata = self.plugin / ".git"
        if (not (metadata / "config").is_file() or (metadata / "config").is_symlink()
                or (metadata / "objects/info/alternates").exists()):
            return False
        # Read only the literal local file, before status can invoke a clean
        # filter. Includes and alternate worktrees are user configuration, not
        # something an unattended replacement should interpret or discard.
        config = self.command("git", "config", "--file", str(metadata / "config"),
                              "--no-includes", "--null", "--list")
        for entry in config.split("\0"):
            key = entry.split("\n", 1)[0].lower()
            if (key.startswith(("filter.", "include.", "includeif.", "extensions."))
                    or key == "core.worktree"):
                return False
        origin = self.git(self.plugin, "config", "--local", "--no-includes", "--get-all", "remote.origin.url").rstrip("/").removesuffix(".git")
        if origin.lower() != REPOSITORY.lower() or not self.clean():
            return False
        try:
            self.verify_tree(self.plugin, self.git(self.plugin, "rev-parse", "HEAD"))
        except (ValueError, OSError):
            return False
        return True

    def install(self, release):
        release_id, tag = release_identity(release)
        target_version = version(tag[1:])
        current = read_local_json(self.plugin / "manifest.json", 16384)
        if not isinstance(current, dict) or current.get("id") != PLUGIN_ID:
            raise ValueError("wrong installed plugin")
        if target_version <= version(current["version"]):
            return "current"
        if release.get("immutable") is not True:
            raise UnverifiedUpdate("release is not immutable")
        expected = self.approval()
        original = self.git(self.plugin, "rev-parse", "HEAD")
        identity = (self.plugin.stat().st_dev, self.plugin.stat().st_ino)
        # Outside plugins/: staging must not be discovered as another widget.
        with tempfile.TemporaryDirectory(prefix=".windowpeek-update-", dir=self.plugin.parent.parent,
                                         ignore_cleanup_errors=True) as temporary:
            stage = Path(temporary) / "plugin"
            stage.mkdir()
            self.git(stage, "init", "--quiet", "--template=", "--initial-branch=main")
            self.git(stage, "remote", "add", "origin", REPOSITORY)
            self.git(stage, "fetch", "--no-tags", REPOSITORY, "refs/tags/" + tag)
            tag_object = self.git(stage, "rev-parse", "FETCH_HEAD")
            target = self.git(stage, "rev-parse", "FETCH_HEAD^{commit}")
            if target != expected:
                raise UnverifiedUpdate("release commit differs from verified snapshot")
            self.git(stage, "fsck", "--full", "--strict")
            self.git(stage, "merge-base", "--is-ancestor", original, target)
            # Reject link entries before checkout, not after following them.
            modes = self.git(stage, "ls-tree", "-r", "--format=%(objectmode)", target).splitlines()
            if not modes or any(mode not in ("100644", "100755") for mode in modes):
                raise ValueError("release contains a symlink or submodule")
            self.git(stage, "checkout", "--quiet", "-B", "main", target)
            manifest = read_local_json(stage / "manifest.json", 16384)
            if not isinstance(manifest, dict) or manifest.get("id") != PLUGIN_ID or manifest.get("version") != tag[1:]:
                raise ValueError("release manifest mismatch")
            self.validate(stage)
            # Re-read both authorities immediately before committing the change.
            # Withdrawn approval, a changed release or an offline check all stop it.
            confirmed = self.latest()
            if (release_identity(confirmed) != (release_id, tag)
                    or confirmed.get("immutable") is not True or self.approval() != expected):
                raise UnverifiedUpdate("release or approval changed during download")
            if self.git(stage, "ls-remote", "--tags", "--refs", REPOSITORY, "refs/tags/" + tag) != tag_object + "\trefs/tags/" + tag:
                raise UnverifiedUpdate("release tag changed during download")
            self.verify_tree(stage, expected)
            # A user can disable updates, edit code or remove the widget while
            # a download is running. Recheck before touching the installed tree.
            if not self.enabled():
                return "disabled"
            if (not self.eligible() or (self.plugin.stat().st_dev, self.plugin.stat().st_ino) != identity
                    or self.git(self.plugin, "rev-parse", "HEAD") != original):
                return "local-changes"
            # Keep the saved opt-out check next to the atomic operation.
            if not self.enabled():
                return "disabled"
            exchange(stage, self.plugin)
        return "updated"

    def run(self, now=None, startup=False):
        """Legacy verifier retained for regression tests; UI and CLI do not call it."""
        if not self.enabled():
            return "disabled"
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        descriptor = os.open(self.state / "updates.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return "busy"
            if not self.enabled():
                return "disabled"
            now = int(time.time()) if now is None else now
            try:
                previous = read_local_json(self.result, 65536)
                if isinstance(previous, dict) and not check_due(previous, now, startup):
                    return "not-due"
            except (OSError, ValueError, KeyError, TypeError):
                pass
            result = {"lastCheck": now, "nextCheck": now + CHECK_INTERVAL, "status": "checking"}
            atomic_json(self.result, result)
            try:
                result["status"] = self.install(self.latest()) if self.eligible() else "local-changes"
            except UnverifiedUpdate as error:
                result.update(status="unverified", reason=str(error))
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
                result["status"] = "failed"
            atomic_json(self.result, result)
            if result["status"] == "updated":
                atomic_json(self.state / "manual-updates.json", {"status": "", "lastCheck": 0})
                try:
                    self.reload()
                except (OSError, subprocess.SubprocessError):
                    result["status"] = "restart-pending"
                    atomic_json(self.result, result)
            return result["status"]


class ManualUpdates(Updater):
    """Published-release discovery and an explicitly approved exact-commit installation."""

    def __init__(self, home, state, source=None):
        # The native command currently uses HOME/.config, not XDG_CONFIG_HOME.
        super().__init__(home, state, Path(home) / ".config")
        self.result = self.state / "manual-updates.json"
        self.source = Path(source) if source is not None else self.plugin

    def eligible(self):
        # Do not update a different copy when this widget runs from a custom path.
        return self.blocked_reason() is None

    def blocked_reason(self):
        if self.plugin.is_symlink() or self.source.resolve() != self.plugin.resolve():
            return "development"
        return None if super().eligible() else "local-copy"

    def enabled(self):
        try:
            prefs = read_local_json(self.state / "preferences.json", 262144)
            return (type(prefs["version"]) is int and prefs["version"] == 1
                    and isinstance(prefs["settings"], dict)
                    and prefs["settings"].get("checkUpdates", True) is True)
        except (OSError, ValueError, KeyError, TypeError, AttributeError):
            return False

    def includes_unverified(self):
        prefs = read_local_json(self.state / "preferences.json", 262144)
        if (not isinstance(prefs, dict) or type(prefs.get("version")) is not int or prefs["version"] != 1
                or not isinstance(prefs.get("settings"), dict)):
            raise ValueError("invalid update preferences")
        value = prefs["settings"].get("includeUnverifiedUpdates", True)
        if type(value) is not bool:
            raise ValueError("invalid release visibility preference")
        return value

    def metadata(self, url, limit=256 * 1024):
        return read_json(url, limit)

    def release_target(self, release):
        """Resolve the release tag, not mutable target_commitish, to one commit."""
        _, tag = release_identity(release)
        if release.get("immutable") is not True:
            raise ValueError("release is not immutable")
        ref = self.metadata("https://api.github.com/repos/Sarr77/WindowPeek/git/ref/tags/" + tag)
        if not isinstance(ref, dict) or ref.get("ref") != "refs/tags/" + tag:
            raise ValueError("release tag reference mismatch")
        obj = ref.get("object")
        if not isinstance(obj, dict):
            raise ValueError("release tag has no target")
        if obj.get("type") == "tag":
            tag_sha = obj.get("sha")
            if not isinstance(tag_sha, str) or not re.fullmatch(r"[a-f0-9]{40}", tag_sha):
                raise ValueError("invalid annotated release tag")
            tag_obj = self.metadata("https://api.github.com/repos/Sarr77/WindowPeek/git/tags/" + tag_sha)
            if not isinstance(tag_obj, dict) or tag_obj.get("tag") != tag:
                raise ValueError("annotated release tag mismatch")
            obj = tag_obj.get("object")
        commit = obj.get("sha") if isinstance(obj, dict) and obj.get("type") == "commit" else None
        if not isinstance(commit, str) or not re.fullmatch(r"[a-f0-9]{40}", commit):
            raise ValueError("release tag does not resolve to a commit")
        return commit

    def inspect(self):
        reason = self.blocked_reason()
        if reason:
            return {"status": "local-changes", "reason": reason}
        original = self.git(self.plugin, "rev-parse", "HEAD")
        release = self.metadata(RELEASE_URL)
        release_id, tag = release_identity(release)
        target = self.release_target(release)
        catalog_release = False
        verified = False
        if not self.includes_unverified():
            catalog = self.metadata(CATALOG_URL, 32 * 1024 * 1024)
            try:
                approved = approved_commit(catalog)
            except UnverifiedUpdate:
                return {"status": "no-verified", "installedCommit": original}
            if approved == original:
                return {"status": "current", "installedCommit": original, "commit": original}
            if approved != target:
                try:
                    approved_manifest = self.metadata("https://raw.githubusercontent.com/Sarr77/WindowPeek/"
                                                      + approved + "/manifest.json")
                    if (not isinstance(approved_manifest, dict) or approved_manifest.get("id") != PLUGIN_ID):
                        raise ValueError("verified manifest mismatch")
                    approved_tag = "v" + approved_manifest["version"]
                    version(approved_tag[1:])
                    release = self.metadata(RELEASE_TAG_URL + approved_tag)
                    release_id, tag = release_identity(release)
                    if tag != approved_tag or self.release_target(release) != approved:
                        raise ValueError("verified release mismatch")
                except (OSError, ValueError, KeyError, TypeError):
                    return {"status": "no-verified", "installedCommit": original}
                target = approved
                catalog_release = True
            verified = True
        result = {"status": "current", "installedCommit": original, "commit": target}
        manifest = self.metadata("https://raw.githubusercontent.com/Sarr77/WindowPeek/"
                                 + target + "/manifest.json")
        if (not isinstance(manifest, dict) or manifest.get("id") != PLUGIN_ID
                or manifest.get("version") != tag[1:]):
            raise ValueError("release manifest mismatch")
        installed = read_local_json(self.plugin / "manifest.json", 16384)
        if version(tag[1:]) < version(installed["version"]):
            return {**result, "status": "ahead"}
        if original == target:
            return result
        comparison = self.metadata("https://api.github.com/repos/Sarr77/WindowPeek/compare/"
                                   + original + "..." + target + "?per_page=1", 2 * 1024 * 1024)
        relation = comparison.get("status") if isinstance(comparison, dict) else None
        if relation == "behind":
            return {**result, "status": "ahead"}
        if relation != "ahead":
            return {**result, "status": "local-changes", "reason": "different-history"}
        result.update(status="available", version=tag[1:], releaseId=release_id,
                      releaseTag=tag, verification="verified" if verified else "unknown")
        if catalog_release:
            result["catalogRelease"] = True
        if verified:
            return result
        try:
            catalog = self.metadata(CATALOG_URL, 32 * 1024 * 1024)
            result["verification"] = "verified" if approved_commit(catalog) == target else "unverified"
        except UnverifiedUpdate:
            result["verification"] = "unverified"
        except (OSError, ValueError, KeyError, TypeError):
            pass  # Unreachable catalog is unknown, never an approval.
        return result

    def check(self, force=False, now=None):
        if not force and not self.enabled():
            return "disabled"
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        descriptor = os.open(self.state / "updates.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return "busy"
            now = int(time.time()) if now is None else now
            try:
                previous = read_local_json(self.result, 65536)
                legacy_block = isinstance(previous, dict) and previous.get("status") == "local-changes" and not previous.get("reason")
                if not force and isinstance(previous, dict) and not legacy_block and not check_due(previous, now):
                    return "not-due"
            except (OSError, ValueError):
                pass
            result = {"lastCheck": now, "nextCheck": now + CHECK_INTERVAL}
            try:
                result.update(self.inspect())
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
                result["status"] = "failed"
            atomic_json(self.result, result)
            return result["status"]

    def install_exact(self, commit, target_version, expected_verification):
        """Install only the checked immutable release and its exact tag commit."""
        if (not isinstance(commit, str) or not re.fullmatch(r"[a-f0-9]{40}", commit)
                or expected_verification not in ("verified", "unverified", "unknown")):
            raise ValueError("invalid update choice")
        version(target_version)
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        descriptor = os.open(self.state / "updates.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return "busy"
            try:
                checked = read_local_json(self.result, 65536)
                if (not isinstance(checked, dict) or checked.get("status") != "available"
                        or checked.get("commit") != commit or checked.get("version") != target_version
                        or checked.get("verification") != expected_verification
                        or type(checked.get("releaseId")) is not int or checked["releaseId"] <= 0
                        or checked.get("releaseTag") != "v" + target_version):
                    return "stale"
                if checked["verification"] != "verified" and not self.includes_unverified():
                    return "stale"
                if not self.eligible():
                    checked["installError"] = "local-changes"
                    atomic_json(self.result, checked)
                    return "local-changes"
                checked["installing"] = True
                checked.pop("installError", None)
                atomic_json(self.result, checked)
                fresh = self.inspect()
                if (fresh.get("status") != "available" or fresh.get("commit") != commit
                        or fresh.get("version") != target_version
                        or fresh.get("releaseId") != checked["releaseId"]
                        or fresh.get("releaseTag") != checked["releaseTag"]
                        or fresh.get("catalogRelease") != checked.get("catalogRelease")
                        or (expected_verification == "verified" and fresh.get("verification") != "verified")):
                    raise ValueError("update changed")
                original = self.git(self.plugin, "rev-parse", "HEAD")
                identity = (self.plugin.stat().st_dev, self.plugin.stat().st_ino)
                with tempfile.TemporaryDirectory(prefix=".windowpeek-update-", dir=self.plugin.parent.parent,
                                                 ignore_cleanup_errors=True) as temporary:
                    stage = Path(temporary) / "plugin"
                    stage.mkdir()
                    self.git(stage, "init", "--quiet", "--template=", "--initial-branch=main")
                    self.git(stage, "remote", "add", "origin", REPOSITORY)
                    self.git(stage, "fetch", "--no-tags", REPOSITORY, "refs/tags/" + checked["releaseTag"])
                    tag_object = self.git(stage, "rev-parse", "FETCH_HEAD")
                    if self.git(stage, "rev-parse", "FETCH_HEAD^{commit}") != commit:
                        raise ValueError("release tag changed during download")
                    self.git(stage, "fsck", "--full", "--strict")
                    self.git(stage, "merge-base", "--is-ancestor", original, commit)
                    modes = self.git(stage, "ls-tree", "-r", "--format=%(objectmode)", commit).splitlines()
                    if not modes or any(mode not in ("100644", "100755") for mode in modes):
                        raise ValueError("update contains a symlink or submodule")
                    self.git(stage, "checkout", "--quiet", "-B", "main", commit)
                    manifest = read_local_json(stage / "manifest.json", 16384)
                    if (not isinstance(manifest, dict) or manifest.get("id") != PLUGIN_ID
                            or manifest.get("version") != target_version):
                        raise ValueError("update manifest mismatch")
                    self.validate(stage)
                    self.verify_tree(stage, commit)
                    release_url = (RELEASE_TAG_URL + checked["releaseTag"]
                                   if checked.get("catalogRelease") is True else RELEASE_URL)
                    latest = self.metadata(release_url)
                    if (release_identity(latest) != (checked["releaseId"], checked["releaseTag"])
                            or self.release_target(latest) != commit):
                        raise ValueError("release changed before installation")
                    if self.git(stage, "ls-remote", "--tags", "--refs", REPOSITORY,
                                "refs/tags/" + checked["releaseTag"]) != tag_object + "\trefs/tags/" + checked["releaseTag"]:
                        raise ValueError("release tag changed before installation")
                    if expected_verification == "verified" or not self.includes_unverified():
                        if approved_commit(self.metadata(CATALOG_URL, 32 * 1024 * 1024)) != commit:
                            raise UnverifiedUpdate("catalog approval changed")
                    if (not self.eligible() or (self.plugin.stat().st_dev, self.plugin.stat().st_ino) != identity
                            or self.git(self.plugin, "rev-parse", "HEAD") != original):
                        raise ValueError("installed copy changed")
                    exchange(stage, self.plugin)
                now = int(time.time())
                atomic_json(self.result, {"status": "current", "installedCommit": commit, "commit": commit,
                                          "lastCheck": now, "nextCheck": now + CHECK_INTERVAL})
                try:
                    self.reload()
                except (OSError, subprocess.SubprocessError):
                    atomic_json(self.result, {"status": "current", "installedCommit": commit, "commit": commit,
                                              "lastCheck": now, "nextCheck": now + CHECK_INTERVAL,
                                              "installError": "restart-pending"})
                    return "restart-pending"
                return "updated"
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
                try:
                    checked = read_local_json(self.result, 65536)
                except (OSError, ValueError, KeyError, TypeError):
                    checked = None
                if isinstance(checked, dict):
                    checked.pop("installing", None)
                    checked["installError"] = "failed"
                    atomic_json(self.result, checked)
                return "failed"

    def confirm_in_terminal(self):
        # This is only invoked by an explicit UI action in a visible terminal.
        # Hold the automatic updater's lock until the native confirmation ends.
        if not os.isatty(0) or not os.isatty(1):
            raise ValueError("manual update requires an interactive terminal")
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        descriptor = os.open(self.state / "updates.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, "w") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print("WindowPeek: another update check is running. Try again shortly.")
                return 1
            if not self.eligible():
                print("WindowPeek: this is not a clean standard installation. No changes made.")
                return 1
            original = self.git(self.plugin, "rev-parse", "HEAD")
            # No remote text enters the command. No --yes, sudo or custom installer.
            result = subprocess.run(["omarchy", "plugin", "update", PLUGIN_ID], check=False).returncode
            if result == 0 and self.git(self.plugin, "rev-parse", "HEAD") != original:
                atomic_json(self.result, {"status": "", "lastCheck": 0})
                try:
                    self.reload()  # A rescan alone can retain old QML components.
                except (OSError, subprocess.SubprocessError):
                    print("WindowPeek was updated. Restart the Omarchy shell to load it.")
            return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--startup", action="store_true", help="Legacy flag; discovery now follows the six-hour schedule")
    manual = parser.add_mutually_exclusive_group()
    manual.add_argument("--check-manual", action="store_true", help="Only check published release metadata")
    manual.add_argument("--manual-update", action="store_true", help="Legacy Omarchy terminal update")
    manual.add_argument("--install-commit", help="Install this already checked exact commit after UI approval")
    parser.add_argument("--install-version", help="Version displayed in the approval prompt")
    parser.add_argument("--expected-verification", choices=("verified", "unverified", "unknown"))
    parser.add_argument("--force", action="store_true", help="Check now, ignoring the cached deadline")
    args = parser.parse_args()
    home = Path.home()
    state = os.environ.get("XDG_STATE_HOME") or str(home / ".local/state")
    if args.manual_update:
        worker = ManualUpdates(home, state, Path(__file__).parent)
        result = 1
        try:
            result = worker.confirm_in_terminal()
            worker.check(force=True)
        except (OSError, ValueError, subprocess.SubprocessError) as error:
            print("WindowPeek: could not start the manual update: " + str(error))
        finally:
            if os.isatty(0):
                try:
                    input("\nPress Enter to close.")
                except (EOFError, KeyboardInterrupt):
                    pass
        raise SystemExit(result)
    if args.install_commit:
        if not args.install_version or not args.expected_verification:
            raise SystemExit(1)
        try:
            result = ManualUpdates(home, state, Path(__file__).parent).install_exact(
                args.install_commit, args.install_version, args.expected_verification)
            print(result)
        except (OSError, ValueError):
            raise SystemExit(1)
        raise SystemExit(0 if result in ("updated", "restart-pending") else 1)
    try:
        print(ManualUpdates(home, state, Path(__file__).parent).check(force=args.force))
    except (OSError, ValueError):
        # An unwritable state directory must not start an unrecorded update.
        raise SystemExit(1)
