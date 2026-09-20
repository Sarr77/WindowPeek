# User guide

## Opening the list

Hover over **WindowPeek** on the bar to see all open windows, grouped by
workspace. The active window appears first. Workspace headings show their
monitor; **Hidden** means the workspace is not currently shown on any monitor.
Scroll with the wheel or drag the scrollbar.

Click the bar label to expand the same panel, adding search, Move and Settings.
The list keeps its position. Clicking unused space inside the list also expands
it; another click on unused space returns to the hover view and clears search.
Buttons, window rows and the scrollbar keep their own actions.

Click the bar label again to close the panel. It will not reopen on hover until
you leave the label and return. Right-clicking the main panel closes it too.
In menus, right-click or Escape goes back one step; inside a dropdown it closes
just that dropdown.

Turn off **Open panel on hover** for a click-only panel. In that mode, clicking
empty space cannot collapse the list.

## Finding and previewing a window

Search matches application names and window titles. It includes each tab in a
Hyprland window group, even inactive tabs. It does not list browser tabs or
documents inside an application separately.

Hover a row to see a content preview. You can move onto the preview and click
it to switch to that window. The gaps between the bar, list and preview keep
them open while you cross. A long preview title wraps to two lines.

Hold **Shift** to hide previews while browsing. A preview under your pointer
stays visible, as does one whose move menu is open. Releasing Shift starts the
usual preview delay. To disable previews permanently, turn off **Window previews**.

Previews stay in memory. A hidden application that stops drawing can show its
last available frame. Previewing a window does not activate it or change workspaces.

## Switching and moving

A plain click switches to the selected window or group tab on its existing
monitor. This also applies to windows in the scratchpad.

**Ctrl + click** a row or preview for a small workspace menu at the pointer.
Search or scroll to a destination, then click it to move the window. **Move to
Scratchpad** stays at the bottom. Opening this menu on a preview keeps the
preview visible. Escape, right-click or an outside click cancels the menu.

**Move** opens a larger form showing the window’s current workspace and monitor.
Choose a destination and press **Move now**, or use **Move to Scratchpad** above
the dropdown. These moves leave your current workspace in place.

**Ctrl + Shift + click** brings the window to the active ordinary workspace of
the monitor containing WindowPeek, then focuses it. It can take a window out of
the scratchpad. If the window is already there, it is simply focused.

Only the selected group member moves. Other members stay where they are;
locked groups are left intact. Destinations include existing workspaces and
numbered workspaces 1–10. A failed move shows an error instead of pretending it worked.

## Keyboard controls

| Key | Action |
| --- | --- |
| ↑ / ↓ in search | Select a result |
| Enter in search | Switch to the selected window |
| Shift + Enter in search | Open its Move form |
| ← / → on a window row | Switch between the window and Move |
| ↑ / ↓ on a row action | Change rows, keeping the same action |
| Hold Ctrl in the window list | Show shortcut numbers beside visible windows and tabs |
| Ctrl + 1–9 / 0 in the window list | Switch to the matching numbered window or tab; 0 means tenth |
| Tab / Shift + Tab | Move through visible controls |
| Enter / Space on a control | Activate it |
| Escape | Close a picker, go back, or close the main list |

Arrows within search text edit the text normally. At the text’s edge, the arrow
toward Move enters that column. Window and Move sides are mirrored in Arabic.
**Controls** in Settings also covers dropdowns, color editing and mouse gestures.

Number shortcuts count the first ten window rows in the visible part of the
list, including individual group tabs; workspace headings do not count. Numbers
start again at 1 as you scroll and update after searching or filtering. They
appear after the app name or the tab marker while Ctrl is held. Turn on
**Shortcut numbers on the right** in **Settings → Window list** to place them
in a vertical column at the right of the second line; **Active** moves to their left.
The default is after the app or tab label. Selecting one
keeps the window on its existing monitor and closes the panel.
A missing position does nothing.
These shortcuts work in hover and the expanded window list, including when Ctrl
was pressed before opening. Hover takes keyboard focus only while Ctrl is held,
then returns it on release without expanding. Settings and move menus keep their own keys.

An optional shortcut can open search on the focused monitor. After checking
that it is free, add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + P", "WindowPeek", 'omarchy-shell sarr.windowpeek toggle ""')
```

Run `hyprctl reload`, then `hyprctl configerrors` to check the configuration.
WindowPeek does not install or replace keybindings for you.

## Settings

Language is at the top. **Automatic** follows your system language; you can
choose any of the 30 translations yourself. Open a category by clicking its
wide header. The header stays in place while its contents expand below it.

- **Panel and previews:** hover mode, content previews, their separate opening
  delays, and popup animations. Both delays start at 400 ms and accept 0–2000 ms.
  Set them to 0 and disable animations for instant popups. Disabled controls
  keep their saved values.
- **Window list:** special workspaces, Spacious or Compact rows, springy
  scrolling, and shortcut-number placement. Compact affects both lists without shrinking the text. Special
  workspaces and springy scrolling start enabled.
- **Personalization:** colors, panel and bar size, bar label and custom text.
- **Controls:** the mouse and keyboard guide.

Switches, language, delays and list choices save as you change them. A failed
save shows an error and leaves the previous choice in effect.

### Colors

Use the palette, hue slider or HEX field. Expand **Color presets** for modes,
per-theme choices and saved colors. **Adapted** uses `#D898F5` in Tokyo Night and
the theme accent elsewhere. **Omarchy accent** always follows the theme;
**Custom** uses your chosen color.

**Only [theme]** keeps a separate choice for that theme. **All themes** uses
one mode everywhere, retaining the individual theme choices for later use.
You can save up to 24 named color presets. Each preset shows its color and HEX code.

**Restore saved color** returns to the last applied color. The **↺** action
returns to Adapted for the scope shown beside it, without deleting presets
or other theme rules. **Apply** saves the draft; Cancel, Back or closing the
panel discards it.

### Interface size

Panel size and bar text scale independently from 80% to 200%. At 100% they
follow Omarchy’s settings. The bar’s height may limit its text size; the editor
shows when this happens. **↺** restores 100%. Apply saves; Cancel or Back undoes
changes, including resets.

### Custom text

Change labels on the bar, panel headings, workspace names, statuses, actions
and hints. Available variables appear beside each field, such as `{count}`
for the bar. Unknown variables prevent Apply.

A blank field uses its translated default. That default stays visible below
the field, and **↺** clears just that override. **Reset all text** clears all
text overrides in the draft. Selecting the Default style keeps your custom
text saved but inactive. Your own text is not translated when changing languages.

Apply saves; Cancel, Back or closing the panel restores the previous text.
Technical settings, errors and the author credit keep their application wording.

## Hints and saved preferences

The **?** button turns hover hints on or off. Automatic hints stop after 200
actual displays, shared across monitors. Turning them back on manually keeps
them on until manually disabled. Hints and content previews are separate.

Preferences are stored outside the plugin in
`~/.local/state/windowpeek/preferences.json`, or `$XDG_STATE_HOME/windowpeek`
if set. They survive restarts, updates and reinstalls. WindowPeek does not
share preferences with ScratchPeek.

For automatic updates, see [update details](UPDATES.md). For installation from
a local source directory, see [development](DEVELOPMENT.md).
