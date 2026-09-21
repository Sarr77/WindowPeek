# Preview artwork

`preview.png` is the README and marketplace image. It illustrates the Wallpaper
style, with the hover list and an Instagram preview in Chromium. Spotify appears
in the list with “Down by the River”. It is a promotional illustration, not a
literal screenshot of the current desktop.

![WindowPeek in Wallpaper style](../preview.png)

The original [PNG](preview-wallpaper.png) is 1774 × 887. The published copy keeps
its original bytes; [preview-render.json](preview-render.json) records its source,
dimensions and SHA256. The earlier editable composition and captures are kept
in [the archive](artwork-history/2026-09-22-before-wallpaper/README.md).

The background is based on Omarchy's
[Tokyo Night winding-road wallpaper](https://github.com/omacom/omarchy/blob/9c9e082954b366bb37e250edf7874856b4172173/themes/tokyo-night/backgrounds/0-winding-road.jpg).
Copyright David Heinemeier Hansson; the [Omarchy MIT notice](../vendor/omarchy/LICENSE)
is retained. Composition and wording: Sarr. Application icons and the content
shown in the window preview belong to their respective owners.

## Prepare a copy

```sh
python3 tools/make_preview.py
# Save a separate PNG without changing the published copy:
python3 tools/make_preview.py --output /tmp/windowpeek-preview.png
```

The command copies the original PNG without resizing, recoloring or re-encoding.
It checks the source hash before writing the output. To render an earlier SVG,
use `--source` and a separate `--output`; this requires `rsvg-convert` from librsvg.

The separate [expanded-panel example](preview-panel.png) uses fictional data
from `tests/artwork/`. To render new example captures:

```sh
python3 tools/render_artwork.py --output-prefix /tmp/windowpeek-ui
```

## Earlier versions

- [Hover panel before Wallpaper](artwork-history/2026-09-22-before-wallpaper/README.md)
- [Expanded panel before the real-window captures](artwork-history/2026-09-21-before-real-windows/README.md)
- [Before the desktop background](artwork-history/2026-09-20-before-desktop-background/README.md)
- [Without a window preview](artwork-history/2026-09-20-before-window-preview/README.md)
- [Original colors](artwork-history/2026-09-20-original/README.md)
