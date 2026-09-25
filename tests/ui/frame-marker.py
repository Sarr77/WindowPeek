"""Report only a synthetic marker's presence; never retain desktop pixels."""
import os
import re
import subprocess

assert os.environ.get("WINDOWPEEK_ISOLATED") == "1", "Private compositor only"
while True:
    result = subprocess.run(["grim", "-o", "WPTEST", "-s", "1", "-t", "ppm", "-"],
                            capture_output=True, timeout=3)
    header = re.match(rb"P6\s+\d+\s+\d+\s+255\s", result.stdout)
    if header:
        print("present" if b"\x11\xee\x44" in result.stdout[header.end():] else "absent", flush=True)
