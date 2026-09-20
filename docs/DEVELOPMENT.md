# Development

WindowPeek is a QML plugin for Omarchy’s Quickshell bar. Its ID is
`sarr.windowpeek`; the source lives at [Sarr77/WindowPeek](https://github.com/Sarr77/WindowPeek).

## Local installation

From the source directory:

```sh
python3 install.py
```

This copies the runtime into `~/.config/omarchy/plugins/sarr.windowpeek` and
enables it on the left of the bar. `XDG_CONFIG_HOME` is respected. A copied
installation has no Git history, so it needs manual updates by rerunning the installer.

For development, link the checkout instead:

```sh
python3 install.py --link
```

After editing runtime code, run `omarchy restart shell`. A plugin rescan can
retain loaded QML types and singletons. The installer also restarts the shell
when replacing an existing installation. Saved preferences are kept.

To remove a local installation:

```sh
python3 install.py remove
```

Preferences remain in `~/.local/state/windowpeek`, or under `XDG_STATE_HOME`.
The installer does not manage shortcuts; see the [user guide](GUIDE.md).

## Checks

```sh
python3 tools/check.py
python3 tools/test_lifecycle.py
```

The first command runs model, update, preferences and offscreen UI checks.
It needs Node.js, Python 3, Qt Quick Test, Quickshell and installed Omarchy
components. The lifecycle test additionally uses bubblewrap to check install,
restart, removal and reinstall in a separate profile without desktop or network access.

Native checks briefly use the desktop and need idle input. See
[Tests](TESTING.md) for commands and limits. See [Architecture](ARCHITECTURE.md)
for responsibilities and [product scope](PRODUCT.md) for supported behavior.

## Package and preview

```sh
python3 tools/package.py
```

This creates `dist/WindowPeek-0.1.0.zip` with source, documentation, licenses
and tests. It excludes Git state, development notes and caches. No commit or
upload is made. The ZIP is a source archive; install it using `install.py`
after extracting it, or use Omarchy’s Git installation for automatic updates.

The root `preview.png` is used by README and the marketplace. Its editable
source is [preview.svg](preview.svg). The panel images use actual QML controls
with fictional windows; see [preview generation](PREVIEW.md).

Publication follows [Publishing](PUBLISHING.md). Public CI checks JavaScript,
Python and packaging; QML and Wayland checks run locally on Omarchy.
