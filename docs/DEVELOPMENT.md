# Development

WindowPeek is a QML plugin for Omarchy’s Quickshell bar. Its ID is
`sarr.windowpeek`; the source lives at [Sarr77/WindowPeek](https://github.com/Sarr77/WindowPeek).

## Installation and development

Install through Omarchy:

```sh
omarchy plugin add https://github.com/Sarr77/WindowPeek --enable
```

Omarchy clones the repository into `~/.config/omarchy/plugins/sarr.windowpeek`
and enables the widget. WindowPeek does not include a separate installer.

For local development, the same command accepts an absolute path to a Git
checkout in place of the URL. It clones committed files; it does not link to
the working directory. The isolated lifecycle test below also tests uncommitted
changes without touching your desktop installation.

After editing installed runtime code, run `omarchy restart shell`. A plugin
rescan can retain loaded QML types and singletons. Saved preferences are kept.

To remove the plugin:

```sh
omarchy plugin remove sarr.windowpeek
```

Preferences remain in `~/.local/state/windowpeek`, or under `XDG_STATE_HOME`.
The enabled widget registers Super + Alt + P if it is unused. No Hyprland config
files are modified. See the [user guide](GUIDE.md#keyboard-controls).

## Checks

```sh
python3 tools/check.py
python3 tools/test_lifecycle.py
```

The first command runs model, update, preferences and offscreen UI checks.
It needs Node.js, Python 3, Lua, Qt Quick Test, Quickshell and installed Omarchy
components. The lifecycle test additionally uses bubblewrap to check install,
restart, removal and reinstall in a separate profile without desktop or network access.

Native checks briefly use the desktop and need idle input. See
[Tests](TESTING.md) for commands and limits. See [Architecture](ARCHITECTURE.md)
for responsibilities and [product scope](PRODUCT.md) for supported behavior.

## Package and preview

```sh
python3 tools/package.py
python3 tools/check_package.py --validate
```

This creates `dist/WindowPeek-<version>.zip` with source, documentation, licenses
and tests. It excludes Git state, development notes, local Python helpers and
caches. No commit or upload is made. The ZIP is a source archive for inspection
and offline checks; use Omarchy’s Git installation above to install the plugin
with automatic updates.

The root `preview.png` is used by README and the marketplace. Its original
PNG is [preview-wallpaper.png](preview-wallpaper.png), a promotional illustration
of the Wallpaper style. Earlier compositions, their SVG sources and captures
are preserved in [the artwork history](PREVIEW.md#earlier-versions). The separate
expanded-panel example uses fictional windows; see [preview artwork](PREVIEW.md).

Publication follows [Publishing](PUBLISHING.md). Public CI checks JavaScript,
Python and packaging; QML and Wayland checks run locally on Omarchy.
