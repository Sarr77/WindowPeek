# Preview artwork

`preview.png` is the README and marketplace image. Its editable source is
[preview.svg](preview.svg), a self-contained 1920 × 960 composition. The
[window list](preview-panel.png) and [content preview](preview-thumbnail.png)
use the application's QML controls. The preview sits beside the list, as it does
in the application. The bar is an illustration.

The windows, editor content and app icons are fictional; their source is in
`tests/artwork/`. The palette uses `#D898F5`. WindowPeek follows other desktop
themes too.

The background is Omarchy's [Tokyo Night winding-road wallpaper](https://github.com/omacom/omarchy/blob/9c9e082954b366bb37e250edf7874856b4172173/themes/tokyo-night/backgrounds/0-winding-road.jpg).
Its original bytes are embedded in the SVG. Copyright David Heinemeier Hansson;
the [Omarchy MIT notice](../vendor/omarchy/LICENSE) is retained.
Composition, example icons and wording: Sarr.

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

The main panel is at `(816, 154)`, sized `600 × 654`; the preview is at
`(1425.6, 197.2)`, sized `384 × 285.6`. Their shadow uses `dy=12`, blur radius
`14` and `#080812` at 45% opacity. Text and icon positions are kept in the SVG.

[preview-render.json](preview-render.json) records image hashes, renderer
versions and fonts. The original rendering used librsvg 2.62.3, Liberation Sans
and JetBrainsMono Nerd Font through Fontconfig's DejaVu substitutions. A different
font setup can change text layout. The default command checks reproduction of
the recorded source before replacing the PNG; use a separate output for review
on another setup.

To refresh the QML captures:

```sh
python3 tools/render_artwork.py --output-prefix /tmp/windowpeek-ui
```

Then replace their embedded images in a copy of the SVG and review the composition
before publishing.

## Earlier versions

- [Before the desktop background](artwork-history/2026-09-20-before-desktop-background/README.md)
- [Without a window preview](artwork-history/2026-09-20-before-window-preview/README.md)
- [Original colors](artwork-history/2026-09-20-original/README.md)
