#!/usr/bin/env python3
"""Check captures from logo-reveal --desktop --image PREFIX on a private GPU."""
import subprocess
import sys

prefix = sys.argv[1]
effects = ["pixels", "scatter", "wipe", "blinds", "iris", "dissolve"]
def pixels(effect, frame):
    return subprocess.check_output(["magick", f"{prefix}.{effect}.{frame}.png", "-depth", "8", "rgba:-"], timeout=5)

reference = pixels("pixels", 2)
alpha = sum(reference[3::4])
assert alpha > 0, "Empty reference image"
pending = subprocess.check_output(["magick", f"{prefix}.pending.png", "-depth", "8", "rgba:-"], timeout=5)
assert sum(pending[3::4]) == 0, "Pending opening flashes the image before the reveal"
middles = []
for effect in effects:
    frames = [pixels(effect, frame) for frame in range(3)]
    assert all(len(frame) == len(reference) for frame in frames)
    coverage = [sum(frame[3::4]) / alpha for frame in frames]
    assert coverage[0] == 0, (effect, "start must be transparent", coverage)
    assert .03 < coverage[1] < .97, (effect, "middle must be partially revealed", coverage)
    assert frames[2] == reference, (effect, "completion changes the original")
    if effect in ("pixels", "scatter"):
        mask = frames[1][3::4]
        edges = sum((a > 127) != (b > 127) for a, b in zip(mask, mask[1:]))
        assert edges > 700, (effect, "expected many separate fragments", edges)
    middles.append(frames[1])
    print(effect, "alpha coverage:", [round(v, 3) for v in coverage], "final image unchanged")
assert len(set(middles)) == len(effects), "Effects must look different"
