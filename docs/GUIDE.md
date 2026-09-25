# User guide

For help choosing a solution, see [Troubleshooting](TROUBLESHOOTING.md).
For confirmed problems and reproduction steps, see [Known Issues](KNOWN_ISSUES.md).

## Opening the list

Hover over **WindowPeek** on the bar to see all open windows, grouped by
workspace. The active window appears first. Workspace headings show their
monitor; **Hidden** means the workspace is not currently shown on any monitor.
Scroll with the wheel or drag the scrollbar.

Click the bar label to expand the same panel, adding search, Move and Settings.
The list keeps its position. The expanded footer shows the installed version
next to **by Sarr**. Clicking unused space inside the list also expands
it; another click on unused space returns to the hover view and clears search.
The middle mouse button also toggles between these views when used on empty
space or a workspace heading. Buttons, window rows and the scrollbar keep their
own left-click actions.

The compact footer shows a subtle Omarchy logo in the theme color. It uses the
space occupied by search and footer controls in the expanded view, keeping their
heights similar. In **Settings → Personalization → Pictures and Gifs**, each logo has its own selector:
plain Omarchy, **Omarchy · Pixel animation**, or a local PNG, JPEG, WebP, SVG or
animated GIF. Changing or restoring one leaves the other unchanged. Each also has
its own visibility switch and, for animations, a **Loop animation** switch and
**Delay loop** field. Looping is on by default; the pause between repetitions
defaults to 4.2 seconds. Enter whole or fractional seconds (`0.3` or `0,3`), then
press Enter or leave the field to save. Zero removes the extra pause. Switching
looping off plays once and holds a GIF's last frame. In Settings, returning from
a submenu resumes the same animation rather than replaying it; a new Settings
visit starts another playback if cooldown permits. The
saved delay stays available when looping is switched back on. **Cooldown** prevents
restarting the animation when reopening the panel too soon: enter seconds or
minutes, including fractions. During that interval the logo stays still. Each
logo keeps its own cooldown, starting when its last animated appearance ends;
zero (the default) allows animation on every opening. The reset arrows restore
4.2 seconds for Delay loop and zero for Cooldown, without changing the other logo.
Enable **Shared cooldown** to use one interval for both logos. Playing either
animation then delays both, even when they use different images. Turning sharing
off restores the separate cooldown values.
Animations stop while hidden.
The chooser shows supported formats: GIF for animation; PNG, JPEG, WebP and SVG
for still images. Browse folders or paste a full file path, preview, then Apply.
The built-in animation
keeps the theme color and translucent wordmark, with a passing pixel glint.
Hover the logo for its own help or a window row for that window's actions.
Hover unused panel space for its expand/collapse gesture. These hints stay below
the panel in both modes and take no space in the list. During the automatic
100-display budget, the footer names **?** in the expanded panel to turn hints off.
Collapsing keeps the old pointer area until you reach the resized
card or leave the old area, so the panel does not disappear under a stationary
pointer, even with the logo disabled.

<img src="preview-panel.png" alt="Expanded WindowPeek panel with search and Move controls" width="490">

Click the bar label again to close the panel. It will not reopen on hover until
you leave the label and return. Right-clicking the main panel closes it too.
Right-click closes the innermost dropdown or editor first. In Settings it collapses
the most recently opened section, regardless of pointer position. Only a further right-click from the collapsed overview returns
to the window list. Escape also closes the nearest inner level. The Back button
skips inner sections and leaves the current editor. Returning from Troubleshooting
follows the route used to enter it, preserving the previous view.
Scrolling outside the panel goes to the application under the pointer.

Turn off **Open panel on hover** for a click-only panel. Enable **Expand on
double-click** in **Settings → Panel and previews** if you prefer a click on
**WindowPeek in the bar** to open the compact view and a double-click to expand
or collapse it. With **Allow pinning compact panel** enabled, the compact view stays
open until you click outside, press Esc or click the bar label again. With it off,
the compact view closes when the pointer leaves, including after collapse. Double-click
unused panel space to switch views; a single click there does not pin or expand
the panel. Middle-click also works. This option works
with hover disabled. Without it, click-only mode always opens the full panel.
Double-click works in both directions directly on the **WindowPeek** bar label,
including when the first click has already opened the compact panel.

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
It follows the selected panel style, including the aligned wallpaper used by
Wallpaper dropdowns.
Search or scroll to a destination, then click it to move the window. **Move to
Scratchpad** stays at the bottom. Any preview already open stays visible while
choosing, whether you open the menu from its row or the preview itself.
Escape, right-click or an outside click cancels the menu.

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
| Super + Alt + P | Open WindowPeek on the focused monitor; show quick-selection numbers for five seconds |
| 1–9 / 0 during quick selection | Switch to the numbered visible window or tab without Ctrl; numpad works with Num Lock on or off |
| Page Up / Page Down in the list | Scroll by a page and select a visible window |
| Home / End in the list | Select the first or last window; in a nonempty search field, move the text cursor |
| ↑ / ↓ in hover or search | Select a result |
| Enter in hover or search | Switch to the selected window |
| Shift + Enter in hover or search | Open its Move form |
| ← / → on a window row | Switch between the window and Move |
| ↑ / ↓ on a row action | Change rows, keeping the same action |
| Hold Ctrl in the window list | Show shortcut numbers beside visible windows and tabs |
| Ctrl + 1–9 / 0 in the window list | Switch to the matching numbered window or tab; 0 means tenth. The numeric keypad works with Num Lock on or off |
| Tab / Shift + Tab | Move through visible controls |
| Enter / Space on a control | Activate it |
| Escape | Close a picker, go back, or close the main list |

Home, End, Page Up/Down and ↑/↓ also work directly in the hover list.
Enter or Space selects its highlighted window. Tab, Shift+Tab and the side arrows
expand the panel to expose its controls; Shift+Enter opens the Move form.
Saved shortcuts apply to both views. Start typing in the hover list to expand it
and search immediately, including from a pinned compact panel. Shortcuts take
priority over text input. Without additional typing protection, compact browsing
follows your mouse-focus settings: moving to another window can focus it, and
hovering WindowPeek again lets you type without clicking. Expanded Search keeps
keyboard focus outside the panel, even with an empty query. Collapsing returns to
compact browsing; closing WindowPeek returns the keyboard to the application.
See the [known X11 exception](#x11-applications-interrupting-search) if typing
stops when the pointer moves over another window.

Arrows within search text edit the text normally. At the text’s edge, the arrow
toward Move enters that column. Window and Move sides are mirrored in Arabic.
**Controls → Keyboard & mouse shortcuts** lets you change WindowPeek’s actions:
opening the panel, the modifier for visible-window numbers, holding a key to hide
previews, moving a selected window, list navigation and modified mouse clicks.
The table above shows the defaults. Number selection always includes the numeric
keypad; the five-second quick selection after keyboard opening stays available.

Click the key combination beside an action. You can record a new combination
or select its modifiers and key with the mouse. Recording starts only when the
compositor grants shortcut protection; if unavailable, use the buttons instead.
Conflicts with another WindowPeek action or an existing Hyprland binding are
shown before saving. Tab, Shift+Tab, Enter, Space and Esc retain normal control
navigation; plain letters remain available for search.

Each row has a reset button. **Restore default shortcuts** resets the whole draft;
**Apply** saves it for both views and all monitors, and **Cancel** discards it.
Help and hover hints follow the saved bindings. Manually added Hyprland shortcuts
remain active alongside WindowPeek’s managed opening shortcut; the editor does
not rewrite your Hyprland configuration.

**Controls** also covers dropdowns, color editing and mouse gestures.

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
was pressed before opening. Holding or releasing Ctrl does not expand the panel;
typing search text does. Settings and move menus keep their own keys.

**Super + Alt + P** is registered automatically when WindowPeek is enabled,
including after installing from the catalog. Existing bindings take precedence;
WindowPeek never replaces one. Its automatic binding is released when the plugin
is disabled or removed and does not edit Hyprland configuration files.

Opening with this shortcut, or the `open`/`toggle` IPC commands, starts a
five-second quick-selection period. Press a visible **1–9 / 0** without Ctrl,
on either the number row or the numeric keypad. Scrolling updates the numbers.
Typing a search query ends quick selection immediately; after five seconds,
digits also become ordinary search text. **Ctrl + 1–9 / 0** remains available.
Opening by mouse keeps the usual search behavior.

To use a different shortcut, choose **Settings → Controls → Keyboard & mouse
shortcuts → Open WindowPeek**. This also works when the default combination
is already assigned to another action.

For a manually managed binding instead, add the following to
`~/.config/hypr/bindings.lua` (replace the key combination as needed):

```lua
o.bind("SUPER + ALT + P", "WindowPeek", 'omarchy-shell sarr.windowpeek toggle ""')
```

Run `hyprctl reload`, then `hyprctl configerrors` to check the configuration.
An existing manual WindowPeek binding to this command also starts quick selection.

## Settings

Language is at the top. **Automatic** follows your system language; you can
choose any of the 30 translations yourself. Open a category by clicking its
wide header. The header stays in place while its contents expand below it.

- **Panel and previews:** hover mode, content previews, their separate opening
  delays, and popup animations. Both delays start at 400 ms and accept 0–2000 ms.
  Set them to 0 and disable animations for instant popups. Disabled controls
  keep their saved values.
- **Window list:** special workspaces, Spacious or Compact rows, springy
  scrolling, mouse-wheel speed, and shortcut-number placement. Wheel speed ranges
  from 50% to 300% in 1% steps and resets to 102%; 100% matches the previous wheel-step distance.
  It applies to both window lists, Settings and selection menus; pixel-based touchpad gestures
  keep their native behavior. Compact affects both lists without shrinking the text. Special
  workspaces and springy scrolling start enabled.
- **Personalization:** panel background, colors, panel and bar size, bar label
  and custom text.
- **Controls:** editable action shortcuts and mouse modifiers, plus the keyboard and mouse guide.

Switches, language, delays and list choices save as you change them. A failed
save shows an error and leaves the previous choice in effect.

### Panel background

With **Wallpaper** selected, **Follow bar style** sits beside its default label.
It is off by default. Enable it to use Solid while the bar is opaque and restore
Wallpaper when the bar is transparent, including changes made by double-clicking
the bar. The saved Wallpaper colors, transparency, blur and grain stay unchanged.
The list, previews and menus follow the same effective style. Selecting Solid or
Transparent uses that choice directly; following the bar applies only to Wallpaper.

Choose a background under **Settings → Personalization**:

- **Solid** uses the usual theme-colored surface.
- **Wallpaper**, the default, shows the current wallpaper, aligned with its position on your
  monitor. Applications behind the panel stay hidden. You can add **Blur wallpaper**
  and **Subtle grain** for a glass effect.
- **Transparency** shows what is actually behind the panel, including other
  windows. It starts at just 8% transparency to keep text easy to read.

The **Transparency** slider runs from 0% to 100%. Wallpaper normally starts at
70%. On first use in a theme, WindowPeek checks the wallpaper beneath the panel.
Only widespread, very poor contrast lowers this initial transparency, including
contrast for small descriptions. Acceptable backgrounds keep their existing value.
The check uses the theme's actual text color: a light wallpaper with readable dark
text can stay at 70%. During a theme switch, it waits for the new colors to load.

Wallpaper remembers the slider and its initial level separately for each theme.
The reset arrow restores **that theme’s initial level**. Your later adjustments
take priority; reopening, restarting or changing wallpaper does not repeat the
automatic adjustment for a theme already initialized. Transparency mode keeps
its separate value and 8% reset level. Existing settings are kept as the starting
point for themes without a saved value.
**Subtle grain** starts enabled and is also available with Transparency.
**Blur wallpaper** starts disabled. Both can be changed independently.

These choices apply to the hover list, search panel and window-preview frame.
Text, icons and the preview itself stay fully visible; rows retain a theme-colored
fill. Wallpaper dropdowns show the matching part of the wallpaper with the same
effects and a stronger tint for readable options. Controls underneath do not
show through. If the wallpaper cannot be loaded, its background falls back to
solid. Wallpaper blur works without changing Hyprland settings;
the Transparency mode follows the compositor’s blur setting when supported.
Switching modes keeps your colors, presets and other preferences.

The **Panel and previews** section also contains **Dark backing behind preview
image**. Turn it off to expose the preview frame’s own background instead of the
dark inset; it does not remove dark areas that belong to the captured application.
**Fit preview to window proportions** is on by default. The card follows portrait
and landscape windows within the monitor’s size limit. Once the first captured
frame sets its proportions, the frame stays the same size until closed. If the
source window is resized, its live image fits inside that frame; reopening the
preview fits the new proportions. Turn it off for the previous fixed frame. The app icon and title remain above the image.

### Colors

The color editor expands to fit its contents when the monitor has enough room.
On smaller screens it uses the available height and keeps the controls scrollable.

Choose **Color element** to edit the accent, panel background, window/tab fields,
menu sections, grain or wallpaper. Colors use the palette, hue slider and HEX
field. Panel, row and menu fills have brightness controls; wallpaper has its
own brightness slider. Row and menu transparency are independent of the main
panel slider. Grain has a separate color and strength.

The panel tint works with Solid, Wallpaper and Transparency. For the accent,
**Adapted** uses `#D898F5` in Tokyo Night and the theme accent elsewhere.
**Omarchy accent** always follows the theme. Other elements can follow their
theme color or use a custom one. The editor preview shows the chosen background
mode, window fields and menu fill.

Click a panel background, window row, accent or menu section in **Live preview**
to select its color element. The preview sits at the top of the editor, above
the controls; clicking does not scroll it away. A contrasting outline marks the
selected element, and the heading names it. Both follow the **Color element**
dropdown as well as clicks on the preview.
Selections retain your draft; **Apply** saves it. The sample rows do not switch
windows. Grain remains selectable through **Color element**.

**Only [theme]** keeps a separate choice for that theme. **All themes** uses
that element’s settings everywhere, retaining individual theme choices for later.
Expand **Appearance presets** to save up to 24 named sets of accent and surface
colors, brightness and field transparency. Applying a preset uses the selected
theme scope. Presets retain theme-following colors; existing single-color
presets still work. Background mode, its main transparency slider, blur and grain
switches remain separate settings.

Each slider has a reset arrow. The element’s **↺** resets its color, brightness
and transparency together. **Restore default colors** restores the default colors,
brightness and field transparency for the selected scope, retaining presets and
other themes. It does not reload a saved preset. **Restore saved color**
restores that element’s last applied settings. **Apply** saves the draft;
Cancel, Back or closing the panel discards changes, including preset edits and
resets.

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

The WindowPeek name on the bar has a contextual hint below the open panel.
It describes pinning or closing when enabled, and the current expand/collapse
gesture. **Panel and previews → Allow pinning compact panel** controls whether
the compact view stays open after a bar click or collapse. The panel's own title
has the same expand/collapse gesture as its background, with no separate pin action.

The **?** button turns hover hints on or off, including logo and control hints.
In both compact and expanded views, hints describe the element under the pointer.
Window actions, logos, empty panel space and footer controls share the panel's
bottom area and appear one at a time. Settings control hints appear beside the
pointer. Automatic hints show how many displays remain and where to turn them off
in the expanded panel.
Automatic hints stop after 100 actual displays, shared across monitors. Turning
them back on manually keeps them on until manually disabled, without a countdown
or status footer. The **?** explanation stays available.
Hints and content previews are separate.

Preferences are stored outside the plugin in
`~/.local/state/windowpeek/preferences.json`, or `$XDG_STATE_HOME/windowpeek`
if set. They survive restarts, updates and reinstalls. WindowPeek does not
share preferences with ScratchPeek.

For automatic updates, see [update details](UPDATES.md). For installation from
a local source directory, see [development](DEVELOPMENT.md).

## Known issues

### X11 applications interrupting search

On Hyprland 0.56.2, some X11 applications repeatedly request a new window size
while tiled. This has been confirmed with RSI Launcher running through Wine.
Hyprland rejects the resize but also moves keyboard focus to the window under
the pointer. As a result, WindowPeek can stop receiving text when the pointer
leaves the panel for another application, or when filtering makes the panel
shrink above a stationary pointer. Pinning the panel does not prevent this Search issue.
Moving over empty desktop space did not trigger the same loss in the reproduced
case.

The trigger is the application's **tiled** window, rather than its ordinary
floating mode. Temporarily making that application floating, or closing it
when not needed, avoids the confirmed trigger. This is a workaround, not a
WindowPeek setting; the plugin does not change other applications' tiling.

The same failure occurs in an independent panel without WindowPeek running.
It does not mean every X11 or Wine application is affected. Other Hyprland
versions have not been verified. There is no complete fix preserving all outside input. Optional protection
modes are described below; their scrolling restrictions are explained before
you choose. WindowPeek never repeatedly forces focus back in a loop.

See the [technical explanation](ARCHITECTURE.md#x11-resize-requests-and-keyboard-focus)
and [test coverage](TESTING.md#search-focus-outside-the-compact-and-expanded-panel).


## Interrupted search with an X11 application

If search loses keyboard focus while a tiled X11 window repeatedly requests a
new size, WindowPeek may show **Typing in search was interrupted → Review options**.
Open it to see alternatives and optional **temporary protection**. It will never
enable protection simply because an application is running.

Protection helps keep typing in the panel, but touchpad scrolling and rapid
wheel movements outside it may fail. The dialog explains this before you choose.
You can instead try giving the affected window more room, making it floating, closing it when unused,
or using its documented native Wayland launch mode where supported. WindowPeek
does not change that application's setup.

**Turn off** stops protection. Closing WindowPeek suspends it; reopening reuses
your choice while that exact affected window exists. Closing the affected
window automatically clears the permission and shows a notification. Restarting
the app or shell requires fresh detection and consent. If the source cannot be
identified, temporary protection lasts until you turn it off or restart the bar,
including across panel reopenings. The notice is currently
translated into English and Polish, with English used for other locales.

## Search loses keyboard focus

Open **Settings → Controls → Troubleshooting** if moving the pointer to another
window interrupts your search. **Keep search focus** is off by default. Enabling
it protects each opened search panel and blocks scrolling outside it, including
touchpad scrolling. Inside scrolling still works. Click outside or press Esc to
close the panel. Turn the option off there to restore normal outside scrolling.

The page explains known causes and alternatives. For details and the separate
optional temporary protection, see [focus recovery](FOCUS_RECOVERY.md).

### Ignoring focus warnings

In **Review options → Ignore warnings**, choose until logout, this identified
application, or all focus warnings. This only mutes advice; it does not change
keyboard behavior or enable protection. **Settings → Controls → Troubleshooting**
keeps the detected application list and lets you restore warnings for each app,
this session or globally. For conditions, the option to give the requesting
window more room, and detection limits, see [Known Issues](KNOWN_ISSUES.md#typing-is-redirected-when-another-application-requests-a-window-resize).

### Text readability

**Settings → Personalization → Text shadow** offers Automatic (default), On and
Off. Automatic adds a small shadow where text may blend into the wallpaper or
transparent background. It estimates wallpaper contrast from a small local image
sample and treats transparent backgrounds conservatively, because the window
behind them can change. It does not capture other applications. On and Off override
that estimate; the choice is saved. Faint letters become opaque, and a weak
mid-tone accent can use the theme text color for readability. Saved colors stay
unchanged; Off restores their original rendering. The shadow follows the letters,
including warning text, preview captions, input placeholders and the active bar label; it does not add
a rectangle behind them. Editable text also receives contrast correction, while
selection and the caret keep their native behavior.
