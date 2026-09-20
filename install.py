#!/usr/bin/env python3
"""Install the local source without a Git commit or a network request."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from update import exchange

PLUGIN_ID = "sarr.windowpeek"


def runtime_files(source):
    for path in sorted(source.iterdir()):
        if path.is_file() and (path.suffix in (".qml", ".js", ".json")
                               or path.name in ("qmldir", "update.py", "LICENSE", "README.md")):
            yield path.relative_to(source)
    for path in sorted((source / "vendor").rglob("*")):
        if path.is_file():
            yield path.relative_to(source)


def owned(path):
    if not path.exists():
        return not path.is_symlink()
    try:
        return json.loads((path / "manifest.json").read_text()).get("id") == PLUGIN_ID
    except (OSError, ValueError, AttributeError):
        return False


def install(source, config_home, link=False):
    source = Path(source).resolve()
    if not owned(source):
        raise ValueError("The source is not WindowPeek")
    target = Path(config_home) / "omarchy/plugins" / PLUGIN_ID
    target.parent.mkdir(parents=True, exist_ok=True)
    if not owned(target):
        raise ValueError("The destination is occupied by another installation")
    if target.is_symlink() and target.resolve() == source and link:
        return target
    if target.resolve() == source:
        raise ValueError("Cannot replace the source directory with itself")
    with tempfile.TemporaryDirectory(prefix=".windowpeek-install-", dir=target.parent.parent) as directory:
        stage = Path(directory) / "plugin"
        if link:
            stage.symlink_to(source, target_is_directory=True)
        else:
            stage.mkdir()
            for relative in runtime_files(source):
                if (source / relative).is_symlink():
                    raise ValueError("Refusing a symlink in the runtime files")
                destination = stage / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source / relative, destination)
        if target.exists() or target.is_symlink():
            exchange(stage, target)
        else:
            os.replace(stage, target)
    return target


def uninstall(config_home):
    target = Path(config_home) / "omarchy/plugins" / PLUGIN_ID
    if not owned(target):
        raise ValueError("Refusing to remove an unrecognized installation")
    if target.is_symlink():
        target.unlink()
    elif target.exists():
        shutil.rmtree(target)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("install", "remove"), nargs="?", default="install")
    parser.add_argument("--link", action="store_true", help="Link this checkout for local development")
    parser.add_argument("--no-shell", action="store_true", help="Do not change the running shell")
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    config = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    if args.action == "install":
        subprocess.run(["omarchy", "plugin", "validate", str(source)], check=True)
        replacing = (config / "omarchy/plugins" / PLUGIN_ID).exists()
        target = install(source, config, args.link)
        if not args.no_shell:
            subprocess.run(["omarchy-shell", "shell", "rescanPlugins"], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["omarchy", "plugin", "enable", PLUGIN_ID, "--section", "left"], check=True)
            if replacing:
                subprocess.run(["omarchy", "restart", "shell"], check=True)
        print(target)
    else:
        if not args.no_shell:
            subprocess.run(["omarchy", "plugin", "disable", PLUGIN_ID], check=True)
        uninstall(config)
        if not args.no_shell:
            subprocess.run(["omarchy-shell", "shell", "rescanPlugins"], check=True, stdout=subprocess.DEVNULL)
        print("WindowPeek removed; saved preferences retained")


if __name__ == "__main__":
    main()
