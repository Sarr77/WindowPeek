#!/usr/bin/env python3
"""Install an immutable, marketplace-verified release into a clean checkout.

Started by the widget, with no persistent service. The worker survives a shell
reload. GitHub identifies the release; Omarchy independently authorizes its SHA.
"""
import ctypes
import fcntl
import hashlib
import json
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
CATALOG_URL = "https://plugins.omarchy.org/catalog.json"
DAY = 86400


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
            prefs = json.loads((self.state / "preferences.json").read_text())
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
        # Only requested for a newer immutable release, not on every daily check.
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
        current = json.loads((self.plugin / "manifest.json").read_text())
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
            manifest = json.loads((stage / "manifest.json").read_text())
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

    def run(self, now=None):
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
                previous = json.loads(self.result.read_text())
                if type(previous["nextCheck"]) in (int, float) and now < previous["nextCheck"] <= now + DAY:
                    return "not-due"
            except (OSError, ValueError, KeyError, TypeError):
                pass
            result = {"lastCheck": now, "nextCheck": now + DAY, "status": "checking"}
            atomic_json(self.result, result)
            try:
                result["status"] = self.install(self.latest()) if self.eligible() else "local-changes"
            except UnverifiedUpdate as error:
                result.update(status="unverified", reason=str(error))
            except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
                result["status"] = "failed"
            atomic_json(self.result, result)
            if result["status"] == "updated":
                try:
                    self.reload()
                except (OSError, subprocess.SubprocessError):
                    result["status"] = "restart-pending"
                    atomic_json(self.result, result)
            return result["status"]


if __name__ == "__main__":
    home = Path.home()
    state = os.environ.get("XDG_STATE_HOME") or str(home / ".local/state")
    try:
        print(Updater(home, state).run())
    except (OSError, ValueError):
        # An unwritable state directory must not start an unrecorded update.
        raise SystemExit(1)
