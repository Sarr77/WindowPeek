#!/usr/bin/env python3
"""Render the preview from its self-contained SVG, without reprocessing a PNG."""
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
    parser.add_argument('--source', type=Path, default=ROOT / 'docs/preview.svg')
    parser.add_argument('--output', type=Path, help='Alternative PNG path; copies its SVG alongside it')
    args = parser.parse_args()
    source = args.source.resolve()
    output = args.output.resolve() if args.output else ROOT / 'preview.png'
    if output == source or output.suffix.lower() != '.png':
        parser.error('--output must be a separate PNG file')
    record = json.loads((ROOT / 'docs/preview-render.json').read_text())
    with tempfile.TemporaryDirectory(prefix='windowpeek-artwork-') as directory:
        rendered = Path(directory) / 'preview.png'
        subprocess.run(['rsvg-convert', '-o', str(rendered), str(source)], check=True)
        if not args.output and hashlib.sha256(source.read_bytes()).hexdigest() == record['svg_sha256']:
            if hashlib.sha256(rendered.read_bytes()).hexdigest() != record['png_sha256']:
                raise SystemExit('Renderer or fonts differ. Use --output to review a separate version; see docs/PREVIEW.md.')
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(rendered, output)
    if args.output and output.with_suffix('.svg') != source:
        shutil.copyfile(source, output.with_suffix('.svg'))
    print(output)


if __name__ == '__main__':
    main()
