#!/usr/bin/env python3
"""Build the README/marketplace artwork from the fictional QML panel capture."""
import argparse
import base64
from pathlib import Path
import re
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--panel', type=Path, default=ROOT / 'docs/preview-panel.png')
parser.add_argument('--thumbnail', type=Path, default=ROOT / 'docs/preview-thumbnail.png')
parser.add_argument('--accent', default='#D898F5', help='Artwork accent in #RRGGBB form')
parser.add_argument('--output', type=Path, help='Alternative PNG path; saves its SVG alongside it')
args = parser.parse_args()
if not re.fullmatch(r'#[0-9a-fA-F]{6}', args.accent):
    parser.error('--accent must be #RRGGBB')
accent = args.accent.upper()
source = args.panel
image = source.read_bytes()
if image[:8] != b'\x89PNG\r\n\x1a\n':
    raise ValueError('Expected a PNG panel capture')
width, height = struct.unpack('>II', image[16:24])
panel_width = 600
panel_height = panel_width * height / width
encoded = base64.b64encode(image).decode('ascii')
svg = f'''<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1440" height="1000" viewBox="0 0 1440 1000">
<title>WindowPeek — find a window and go straight to it</title>
<desc>An Omarchy bar plugin by Sarr. Search windows across monitors, preview their contents, and move them between workspaces. The panel shows fictional windows.</desc>
<defs>
  <linearGradient id="background" x2="1" y2="1"><stop stop-color="#151a2c"/><stop offset="1" stop-color="#101321"/></linearGradient>
  <radialGradient id="glow"><stop stop-color="#ab66d9" stop-opacity=".14"/><stop offset="1" stop-color="#ab66d9" stop-opacity="0"/></radialGradient>
  <style>
    text {{ font-family: "DejaVu Sans", sans-serif; fill: #e1e5f4; }}
    .muted {{ fill: #a2adc8; }}
    .accent {{ fill: {accent}; }}
    .mono {{ font-family: "DejaVu Sans Mono", monospace; }}
  </style>
</defs>
<rect width="1440" height="1000" fill="url(#background)"/>
<ellipse cx="1090" cy="420" rx="520" ry="520" fill="url(#glow)"/>
<path d="M64 72h38" stroke="{accent}" stroke-width="4" stroke-linecap="round"/>
<text x="120" y="80" class="muted" font-size="20">An Omarchy bar plugin</text>
<text x="64" y="179" font-size="72" font-weight="700" letter-spacing="-2">WindowPeek</text>
<text x="66" y="232" font-size="27">Find a window and go straight to it.</text>
<text x="66" y="268" class="muted" font-size="22">Across workspaces, tabs and monitors.</text>

<rect x="64" y="308" width="532" height="60" rx="12" fill="#202338" stroke="#383b55"/>
<text x="85" y="347" class="mono muted" font-size="18">1  2  3</text>
<text x="224" y="347" class="mono accent" font-size="19">WindowPeek · 5</text>
<path d="M222 366h175" stroke="{accent}" stroke-width="2"/>

<text x="64" y="440" class="accent mono" font-size="18">01</text>
<text x="110" y="440" font-size="25" font-weight="700">One list, every window</text>
<text x="110" y="477" class="muted" font-size="20">Hover to browse. Click to search.</text>
<text x="110" y="508" class="muted" font-size="20">Scratchpad and grouped tabs included.</text>

<text x="64" y="580" class="accent mono" font-size="18">02</text>
<text x="110" y="580" font-size="25" font-weight="700">Peek before you switch</text>
<text x="110" y="617" class="muted" font-size="20">Hover a row for a window preview.</text>
<text x="110" y="648" class="muted" font-size="20">Hold Ctrl to browse without previews.</text>

<text x="64" y="720" class="accent mono" font-size="18">03</text>
<text x="110" y="720" font-size="25" font-weight="700">Move it where you need it</text>
<text x="110" y="757" class="muted" font-size="20">Ctrl + click to choose a workspace.</text>
<text x="110" y="788" class="muted" font-size="20">Ctrl + Shift + click to bring it here.</text>

<text x="724" y="159" class="muted" font-size="17">SEARCH, SWITCH &amp; MOVE</text>
<rect x="715" y="194" width="610" height="{panel_height + 12:g}" rx="16" fill="#070a15" opacity=".5"/>
<image x="720" y="184" width="{panel_width}" height="{panel_height:g}" xlink:href="data:image/png;base64,{encoded}"/>
<text x="1320" y="{panel_height + 212:g}" text-anchor="end" class="muted" font-size="15">Example windows · Colors follow your theme</text>

<path d="M64 888h1256" stroke="#33394f"/>
<g font-size="18">
  <rect x="64" y="908" width="180" height="44" rx="22" fill="#27283e"/>
  <text x="154" y="937" text-anchor="middle">30 languages</text>
  <rect x="260" y="908" width="188" height="44" rx="22" fill="#27283e"/>
  <text x="354" y="937" text-anchor="middle">Your own labels</text>
  <rect x="464" y="908" width="210" height="44" rx="22" fill="#27283e"/>
  <text x="569" y="937" text-anchor="middle">Saved preferences</text>
</g>
<text x="1320" y="932" text-anchor="end" font-size="21">by Sarr</text>
<text x="1320" y="967" text-anchor="end" class="muted" font-size="17">github.com/Sarr77/WindowPeek</text>
</svg>'''
# Keep the main panel at its full size; the preview occupies its empty right side.
thumbnail = args.thumbnail.read_bytes()
if thumbnail[:8] != b'\x89PNG\r\n\x1a\n':
    raise ValueError('Expected a PNG window preview')
thumb_width, thumb_height = struct.unpack('>II', thumbnail[16:24])
shown_width = 384
shown_height = shown_width * thumb_height / thumb_width
encoded_thumbnail = base64.b64encode(thumbnail).decode('ascii')
overlay = f'''
<!-- Production preview card, with a fictional editor window inside it.
     The original panel remains exactly the same size and position. -->
<defs>
  <filter id="previewShadow" x="-.2" y="-.2" width="1.4" height="1.5">
    <feGaussianBlur stdDeviation="10"/>
  </filter>
</defs>
<rect x="1016" y="423" width="{shown_width}" height="{shown_height:g}" rx="10"
      fill="#060811" opacity=".7" filter="url(#previewShadow)"/>
<image x="1016" y="412" width="{shown_width}" height="{shown_height:g}"
       xlink:href="data:image/png;base64,{encoded_thumbnail}"/>
<path transform="translate(-54 0)" d="M1163 368v29l7-7 6 12 5-3-6-11h10z" fill="#e1e5f4"
      stroke="#101321" stroke-width="2" stroke-linejoin="round"/>
'''
svg = svg.replace('</svg>', overlay + '</svg>')
png = args.output if args.output else ROOT / 'preview.png'
output = png.with_suffix('.svg') if args.output else ROOT / 'docs/preview.svg'
output.write_text(svg)
subprocess.run(['rsvg-convert', '--output', str(png), str(output)], check=True)
print(png)
