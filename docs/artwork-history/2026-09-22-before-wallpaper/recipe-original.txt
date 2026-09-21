# Preview artwork

`preview.png` is the README and marketplace image. Its editable source is
[preview.svg](preview.svg), a self-contained 1920 × 960 composition. The
[hover list](preview-hover.png) and [content preview](preview-thumbnail.png)
use the application's QML controls. The preview sits beside the list, as it does
in the application. The bar is an illustration.

The hover list shows real application windows and Hyprland group tabs. The
content preview is Instagram in Chromium; Spotify appears in the list with
“Down by the River”. Both captures use WindowPeek’s QML controls and desktop
application icons. The palette uses `#D898F5`; other desktop themes work too.

The background is Omarchy's [Tokyo Night winding-road wallpaper](https://github.com/omacom/omarchy/blob/9c9e082954b366bb37e250edf7874856b4172173/themes/tokyo-night/backgrounds/0-winding-road.jpg).
Its original bytes are embedded in the SVG. Copyright David Heinemeier Hansson;
the [Omarchy MIT notice](../vendor/omarchy/LICENSE) is retained.
Composition and wording: Sarr. Application icons and the content shown in
the window preview belong to their respective owners.

## Reproduce the image

```sh
python3 tools/make_preview.py
# Save a separate PNG and SVG for comparison:
python3 tools/make_preview.py --output /tmp/windowpeek-preview.png
```

Each render starts from the SVG's original wallpaper, UI captures and vector
elements. Never use an earlier composed PNG as a background. `rsvg-convert`
from librsvg is required; no desktop capture is involved.

The left shading is one `#10101D` gradient with 17 stops. For `i = 0…16`, the
offset is `0.72 × i / 16` and opacity is `0.72 × (1 + cos(π × i / 16)) / 2`,
rounded to five decimal places. Opacity remains zero beyond 72% of the width.
There is no global or bottom darkening. The wallpaper is centered and cropped,
with its proportions preserved.

The main panel is at `(816, 154)`, sized `600 × 757.1429`; the preview is at
`(1427.4286, 221.1429)`, sized `457.1429 × 340`. Their shadow uses `dy=12`, blur radius
`14` and `#080812` at 45% opacity. Text and icon positions are kept in the SVG.

[preview-render.json](preview-render.json) records image hashes, renderer
versions and fonts. The original rendering used librsvg 2.62.3, Liberation Sans
and JetBrainsMono Nerd Font through Fontconfig's DejaVu substitutions. A different
font setup can change text layout. The default command checks reproduction of
the recorded source before replacing the PNG; use a separate output for review
on another setup.

The separate [expanded-panel example](preview-panel.png) uses fictional data
from `tests/artwork/`. To render new example captures:

```sh
python3 tools/render_artwork.py --output-prefix /tmp/windowpeek-ui
```

To update the main artwork, take new captures, replace their embedded images
in a copy of the SVG, and review the composition before publishing. The SVG
already contains everything needed to reproduce the current image; the original
windows do not need to be open.

## Earlier versions

- [Expanded panel before the real-window captures](artwork-history/2026-09-21-before-real-windows/README.md)

- [Before the desktop background](artwork-history/2026-09-20-before-desktop-background/README.md)
- [Without a window preview](artwork-history/2026-09-20-before-window-preview/README.md)
- [Original colors](artwork-history/2026-09-20-original/README.md)
