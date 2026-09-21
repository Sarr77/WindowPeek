"""Choose a conservative first-use Wallpaper default from its local panel crop."""
import json
import math
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


def rgb(value):
    if not isinstance(value, str) or len(value) != 7 or not value.startswith("#"):
        raise ValueError("Expected RGB color")
    return tuple(bytes.fromhex(value[1:]))


def palette_matches(state):
    """Reject the gap between theme.name changing and the shell applying colors."""
    directory = Path(state["directory"])
    if (directory.parent / "theme.name").read_text().strip() != state["theme"]:
        return False
    colors = dict(re.findall(r'^\s*([\w-]+)\s*=\s*[\"\']?(#[0-9A-Fa-f]{6})',
                             (directory / "colors.toml").read_text(), re.MULTILINE))
    for role, fallback in (("foreground", "color7"), ("background", "color0")):
        expected = colors.get(role, colors.get(fallback))
        if not expected or rgb(expected) != rgb(state[role]):
            return False
    # Match Color.parseShell's flat raw roles, including theme overrides of popup
    # colors. Machine-level overrides are already represented by the live colors.
    shell = {}
    section = ""
    shell_path = directory / "shell.toml"
    for line in shell_path.read_text().splitlines() if shell_path.exists() else []:
        heading = re.fullmatch(r'\s*\[([\w-]+)\]\s*(?:#.*)?', line)
        if heading:
            section = heading[1]
            continue
        pair = re.fullmatch(r'\s*([\w-]+)\s*=\s*(?:[\"\']([^\"\']+)[\"\']|(-?\d+(?:\.\d+)?(?:\s+-?\d+(?:\.\d+)?){0,3}|[A-Za-z][\w-]*))\s*(?:#.*)?', line)
        if section and pair:
            shell[section + "." + pair[1]] = pair[2] if pair[2] is not None else pair[3]
    return shell == state["shell"]


def luminance(color):
    # https://www.w3.org/WAI/WCAG22/Understanding/relative-luminance.html
    channels = [c / 255 for c in color]
    return sum(w * (c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4)
               for w, c in zip((.2126, .7152, .0722), channels))


def recommend(samples, foreground, tint, transparency, brightness=0):
    brightness = max(-1, min(1, brightness))
    samples = [tuple(max(0, min(255, c + brightness * 255)) for c in sample) for sample in samples]

    def ratios(value, text_opacity=1):
        alpha = value / 100
        result = []
        for sample in samples:
            back_color = [c * alpha + t * (1 - alpha) for c, t in zip(sample, tint)]
            text_color = [c * text_opacity + b * (1 - text_opacity) for c, b in zip(foreground, back_color)]
            low, high = sorted((luminance(back_color), luminance(text_color)))
            result.append((high + .05) / (low + .05))
        return sorted(result)

    base = max(0, min(100, round(transparency)))
    if not samples:
        return base
    initial = ratios(base)
    # Deliberately leave merely imperfect backgrounds alone. This is a fallback
    # for widespread, extreme contrast loss, not an accessibility conformance test.
    if initial[len(initial) // 2] >= 2.5 or sum(c < 2 for c in initial) / len(initial) < .25:
        return base
    if ratios(0)[0] < 3:
        return base  # Do not change the user's colors to repair an unsuitable tint.
    # Secondary descriptions use 65% text opacity. Once the severe gate passes,
    # protect those small labels too, rather than stopping at barely legible titles.
    target = min(4.5, ratios(0, .65)[0] * .98)
    for candidate in range(base - 1, -1, -1):
        values = ratios(candidate, .65)
        if values[len(values) // 10] >= target:
            return candidate
    return base


def sample_wallpaper(source, screen, panel, tint=(0, 0, 0)):
    url = urlsplit(source)
    if url.scheme != "file" or url.netloc not in ("", "localhost"):
        raise ValueError("Wallpaper must be a local file")
    path = Path(unquote(url.path)).resolve(strict=True)
    if not path.is_file():
        raise ValueError("Wallpaper is not a file")
    if len(screen) != 2 or len(panel) != 4 or not all(
            isinstance(v, (int, float)) and math.isfinite(v) for v in [*screen, *panel]):
        raise ValueError("Invalid geometry")
    sw, sh = screen
    x, y, w, h = panel
    if not (0 < sw <= 32768 and 0 < sh <= 32768 and w > 0 and h > 0):
        raise ValueError("Invalid screen")
    scale = 256 / max(sw, sh)
    width, height = max(1, round(sw * scale)), max(1, round(sh * scale))
    left, top = max(0, round(x * scale)), max(0, round(y * scale))
    right, bottom = min(width, round((x + w) * scale)), min(height, round((y + h) * scale))
    if right <= left or bottom <= top:
        raise ValueError("Panel is outside screen")
    result = subprocess.run([
        "magick", "-limit", "memory", "128MiB", "-limit", "map", "256MiB",
        str(path) + "[0]", "-auto-orient", "-thumbnail", f"{width}x{height}^",
        "-gravity", "center", "-extent", f"{width}x{height}", "-gravity", "northwest",
        "-crop", f"{right-left}x{bottom-top}+{left}+{top}", "+repage",
        "-resize", "32x32!", "-colorspace", "sRGB", "-background", "#" + bytes(tint).hex(),
        "-alpha", "remove", "-alpha", "off", "-depth", "8", "rgb:-",
    ], capture_output=True, timeout=2, check=True)
    if len(result.stdout) != 32 * 32 * 3:
        raise ValueError("Unexpected image data")
    return [tuple(result.stdout[i:i + 3]) for i in range(0, len(result.stdout), 3)]


def main():
    try:
        args = json.loads(sys.argv[1])
        theme_state = args.get("themeState")
        if theme_state is not None and not palette_matches(theme_state):
            print(json.dumps({"retry": True}))
            return 0
        base = args["transparency"]
        brightness = args.get("brightness", 0)
        if not all(isinstance(v, (int, float)) and math.isfinite(v) for v in (base, brightness)):
            raise ValueError("Invalid appearance")
        foreground, tint = rgb(args["foreground"]), rgb(args["tint"])
        samples = sample_wallpaper(args["source"], args["screen"], args["panel"], tint)
        value = recommend(samples, foreground, tint, base, brightness)
        if theme_state is not None and not palette_matches(theme_state):
            print(json.dumps({"retry": True}))
            return 0
        print(json.dumps({"value": value}))
    except (ValueError, KeyError, IndexError, OSError, subprocess.SubprocessError):
        # No files, screenshots, titles or diagnostic image data leave the helper.
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
