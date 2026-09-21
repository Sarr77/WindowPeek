#!/usr/bin/env python3
"""Copy the current preview unchanged, or render an archived SVG for comparison."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, help='Alternative PNG or SVG; requires --output')
    parser.add_argument('--output', type=Path, help='Alternative PNG path; SVG sources are copied alongside it')
    args = parser.parse_args()
    if args.source and not args.output:
        parser.error('--source requires --output to preserve the current preview')
    record = json.loads((ROOT / 'docs/preview-render.json').read_text())
    source = args.source.resolve() if args.source else ROOT / record['source']
    output = args.output.resolve() if args.output else ROOT / 'preview.png'
    if output == source or output.suffix.lower() != '.png':
        parser.error('--output must be a separate PNG file')
    if not args.source and hashlib.sha256(source.read_bytes()).hexdigest() != record['png_sha256']:
        raise SystemExit('Preview source differs from its recorded hash; see docs/PREVIEW.md.')
    if source.suffix.lower() == '.png':
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, output)
        print(output)
        return
    if source.suffix.lower() != '.svg':
        parser.error('--source must be a PNG or SVG file')
    with tempfile.TemporaryDirectory(prefix='windowpeek-artwork-') as directory:
        rendered = Path(directory) / 'preview.png'
        subprocess.run(['rsvg-convert', '-o', str(rendered), str(source)], check=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(rendered, output)
    if args.output and output.with_suffix('.svg') != source:
        shutil.copyfile(source, output.with_suffix('.svg'))
    print(output)


if __name__ == '__main__':
    main()
