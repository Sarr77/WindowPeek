# WindowPeek

Find a window and go straight to it.

WindowPeek puts your open windows in one list on Omarchy’s bar. Search across
workspaces and monitors, peek at a window before switching to it, or move it
somewhere else. Tabs in Hyprland window groups appear separately.

[Polski](docs/README.pl.md) · [User guide](docs/GUIDE.md) · [Changelog](CHANGELOG.md)

![WindowPeek window list, search and workspace controls](preview.png)

## Installation

```sh
omarchy plugin add https://github.com/Sarr77/WindowPeek --enable
```

The widget appears on the left of the bar. You can move it in Omarchy’s bar editor.

Requires Omarchy Quattro with its Quickshell bar and Hyprland’s Lua window API.
Tested on Omarchy 4.0.4, Hyprland 0.56.2, Quickshell 0.3.1 and Qt 6.11.2.
Installation and automatic updates use Python 3 and Git, already included in Omarchy.
See the [development guide](docs/DEVELOPMENT.md) for local and linked installs.

## Using it

Hover over **WindowPeek** for the window list. Click its name to expand the same
panel and search by application or window title. Scroll to see the rest of the
list. Click the bar label again to close it.

| In either window list | Action |
| --- | --- |
| Click a window or its preview | Switch to that window or tab on its original monitor |
| **Ctrl + click** | Open a small menu to choose its workspace |
| **Ctrl + Shift + click** | Bring it to this monitor’s current workspace and focus it |
| Hold **Ctrl** | Hide content previews while browsing the list |
| Right-click the main panel | Close WindowPeek and its preview |

Hold **Ctrl** to browse without showing window previews — useful while streaming
or sharing your screen. Window titles remain visible.

The expanded panel also has **Move** buttons and keyboard navigation. Use ↑ / ↓
to select a window, ← / → to switch between the window and Move, and Enter to
activate it. **Controls** in Settings lists all gestures and shortcuts.
To add the optional **Super + Alt + P** shortcut, follow the
[keyboard setup](docs/GUIDE.md#keyboard-controls).

Scratchpad and other special workspaces are included by default. Browser tabs
and documents inside an application are not separate windows in this list.
A hidden application that stops drawing may show its last available preview frame.

## Settings

Choose from 30 languages, change colors, adjust panel and bar size, or write
your own labels. Colors, size and text preview as you edit them; **Apply** saves
and **Cancel** restores the previous settings. The **↺** icon restores a default.

You can use a click-only panel, disable window previews, choose a compact list,
or turn off springy scrolling. The bar and window previews have separate delays;
set both to **0** and turn off **Popup animations** for instant opening.

The **?** button controls hover hints. They start enabled and stop after 200
displays across all monitors. Turn them back on yourself and they stay on until
you switch them off. Settings survive restarts, updates and reinstalls.

## Updates

Automatic updates are on by default and checked once a day while WindowPeek
runs. Only immutable GitHub releases whose exact commit is verified in the
Omarchy catalog can be installed. Failed downloads or checks leave the existing
installation in place.

The small switch beside **?** turns updates off after confirmation. Development
links, forks, copied installations and locally modified code are not updated
automatically. See [update details and limits](docs/UPDATES.md).

## Removal

```sh
omarchy plugin remove sarr.windowpeek
```

Your windows stay where they are. Preferences remain in
`~/.local/state/windowpeek/preferences.json`, or `$XDG_STATE_HOME/windowpeek`
if set. Delete the preferences file after removal if you also want to reset them.
If you added a keyboard shortcut, remove that binding too.

## Data and permissions

WindowPeek reads local window and monitor state, themes and application icons.
It uses `hyprctl` to switch or move windows. Content previews stay in memory
and are released when dismissed; window titles and previews are not saved to disk.
It does not change your keybindings.

Automatic updates contact GitHub and the Omarchy catalog. Check times and
results are stored beside your preferences. There is no telemetry. WindowPeek
runs inside Omarchy’s shell with your user permissions, without administrator access.

## Help and development

[Report a bug](https://github.com/Sarr77/WindowPeek/issues) ·
[Development](docs/DEVELOPMENT.md) · [Tests and limitations](docs/TESTING.md)

MIT · © 2026 [Sarr](https://github.com/Sarr77).
Selected components come from [ScratchPeek](https://github.com/Sarr77/ScratchPeek);
adapted Omarchy controls and the logo retain
[their MIT notice](vendor/omarchy/LICENSE). See [source provenance](docs/SCRATCHPEEK_REFERENCE.md).
