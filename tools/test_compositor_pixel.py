#!/usr/bin/env python3
"""Check a tiny fictional test marker in the final compositor output."""
import re
import subprocess
import sys

x, y = (int(value) for value in sys.argv[1:])
result = subprocess.run(['grim', '-s', '1', '-t', 'ppm', '-g', f'{x},{y} 4x4', '-'],
                        capture_output=True, check=True, timeout=3)
header = re.match(rb'P6\s+(\d+)\s+(\d+)\s+255\s', result.stdout)
if not header:
    raise SystemExit('Unsupported compositor image format')
width, height = (int(value) for value in header.groups())
pixels = result.stdout[header.end():]
assert len(pixels) == width * height * 3
expected = (17, 238, 68)
matches = sum(all(abs(pixels[i + c] - expected[c]) <= 12 for c in range(3))
              for i in range(0, len(pixels), 3))
if matches < width * height * .95:
    raise SystemExit(f'Menu is obscured: {matches}/{width * height} marker pixels visible')
print('PASS menu marker is above the retained preview')
