# Omarchy logo effects

37 animations from [omacom/ttfx](https://github.com/omacom/ttfx), pinned to
`702b630512e76dc8edcbba47cf948e857bed8d77`, `docs/effects/*.gif`.
The effects are by ChrisBuilds, from TerminalTextEffects; ttfx is the Rust port
by 37signals / omacom-io. Original MIT license and NOTICE are retained here.
The wordmark is Omarchy's. These are bundled animation assets, not runtime code.

`tools/import_logo_effects.py` coalesces the original frame disposal, removes only
the exact backdrop color sampled from the corner, and exports a still of the final frame. Original timing,
canvas proportions and effect colors are retained. Nothing is fetched or generated
at runtime. `sources.json` records original and prepared checksums.

Transparent frames explicitly clear the previous frame (`Background` disposal).
The importer verifies every decoded frame against its source: exact transparency,
colours, geometry and timing. Dithering is disabled so GIF re-encoding does not
introduce new colours. Leaving the original `None` disposal after
removing the opaque backdrop would accumulate moving characters over the logo.

Only the selected animation is decoded. Library rows contain text, not concurrently
running movies. Theme colors are a display option; original colors are retained.
