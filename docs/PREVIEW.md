# Preview artwork

`preview.png` is the README and marketplace image. The composition is in
[preview.svg](preview.svg), built by `tools/make_preview.py`. It includes the
[window list](preview-panel.png) and [content preview](preview-thumbnail.png),
both rendered with the application's QML controls.

The windows, editor content and app icons are fictional examples. Their source
is in `tests/artwork/`. The preview overlaps the list in this composition;
in the application it opens beside the list. The fixed example palette uses
`#D898F5` and does not change the desktop theme.

Earlier artwork is preserved: [original colors](artwork-history/2026-09-20-original/README.md)
and [the version without a window preview](artwork-history/2026-09-20-before-window-preview/README.md).

To refresh the captures on an Omarchy development machine:

```sh
python3 tools/render_artwork.py --output-prefix /tmp/windowpeek-preview
cp /tmp/windowpeek-preview-panel.png docs/preview-panel.png
cp /tmp/windowpeek-preview-hover.png docs/hover-preview.png
cp /tmp/windowpeek-preview-thumbnail.png docs/preview-thumbnail.png
python3 tools/make_preview.py
```

Rendering runs offscreen and does not capture the desktop. The composition
builder additionally needs `rsvg-convert` from librsvg. Review the PNG before
publishing; if the panel size changes, adjust the composition in the builder.
The SVG is self-contained and can also be opened in a vector editor.

To compare another accent without replacing the current artwork, pass a separate
capture and output path. The matching SVG is saved beside the PNG:

```sh
python3 tools/make_preview.py --panel /tmp/windowpeek-preview-panel.png \
  --thumbnail /tmp/windowpeek-preview-thumbnail.png \
  --accent '#D898F5' --output /tmp/windowpeek-alternative.png
```

Artwork, example icons and wording: Sarr. The running application uses the icons
provided by each installed app and the desktop icon theme.
