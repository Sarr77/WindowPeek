"""Bounded virtual-keyboard support for coordinated desktop tests only."""
from contextlib import contextmanager
from pathlib import Path
import select
import shlex
import subprocess


def build_keyboard(root: Path, profile: Path) -> Path:
    protocol = root / "tests/protocols/virtual-keyboard-unstable-v1.xml"
    subprocess.run(["wayland-scanner", "client-header", str(protocol), str(profile / "virtual-keyboard-client.h")], check=True)
    subprocess.run(["wayland-scanner", "private-code", str(protocol), str(profile / "virtual-keyboard.c")], check=True)
    flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "wayland-client", "xkbcommon"], text=True))
    binary = profile / "control-key"
    subprocess.run(["cc", "-Wall", "-Wextra", "-Werror", "-I", str(profile), str(root / "tests/control-key.c"),
                    str(profile / "virtual-keyboard.c"), "-o", str(binary), *flags], check=True)
    return binary


def build_pointer_frame(root: Path, profile: Path) -> Path:
    protocol = root / "tests/protocols/wlr-virtual-pointer-unstable-v1.xml"
    subprocess.run(["wayland-scanner", "client-header", str(protocol), str(profile / "virtual-pointer-client.h")], check=True)
    subprocess.run(["wayland-scanner", "private-code", str(protocol), str(profile / "virtual-pointer.c")], check=True)
    flags = shlex.split(subprocess.check_output(["pkg-config", "--cflags", "--libs", "wayland-client"], text=True))
    binary = profile / "pointer-frame"
    subprocess.run(["cc", "-Wall", "-Wextra", "-Werror", "-I", str(profile), str(root / "tests/pointer-frame.c"),
                    str(profile / "virtual-pointer.c"), "-o", str(binary), *flags], check=True)
    return binary


@contextmanager
def held_keys(binary: Path, key="Control_L", shift=None):
    command = [str(binary), key] + ([shift] if shift else [])
    process = subprocess.Popen(command, text=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        if not select.select([process.stdout], [], [], 3)[0] or process.stdout.readline().strip() != "pressed":
            raise AssertionError("Virtual keyboard did not press the requested keys")
        yield process
    finally:
        try:
            _, error = process.communicate(input="\n", timeout=3)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.communicate(timeout=3)
            raise
        if process.returncode:
            raise AssertionError("Virtual keyboard failed: " + error)
