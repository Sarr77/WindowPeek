# Settings guide

Open **Settings** from the expanded WindowPeek panel. This guide follows the
same order as its sections and subpages. Defaults describe a new installation;
updates preserve your saved choices.

[Language](#language) · [Panel and previews](#panel-and-previews) ·
[Window list](#window-list) · [Personalization](#personalization) ·
[Controls](#controls) · [Defaults](#defaults)

## Saving and navigation

Switches and simple selectors save immediately. Editors with **Apply / Cancel**
keep a draft until you apply it; the artwork chooser uses **Use this / Cancel**.
A failed save leaves the previous setting in effect. **↺** restores the relevant
default; an editor reset is still part of its draft until saved.

**Back** returns to the previous page. The pin beside it keeps the panel open
while you use another application; it does not keep the keyboard away from that
application. **Close** dismisses a pinned panel. A new opening starts unpinned.

## Language

**Automatic** follows your system language. You can select any of the 30
translations instead. Custom labels remain exactly as you wrote them.

## Panel and previews

| Control | What it changes | Default |
| --- | --- | --- |
| Open panel on hover | Browse windows by pointing at the bar label | On |
| Bar hover delay | Wait before showing the compact panel; 0 means instant | 400 ms |
| Expand on double-click | Single click opens compact; double-click expands or collapses. Turn off for single-click expansion | On |
| Allow pinning compact panel | Keep compact open after a bar click or collapse; otherwise it closes on pointer exit | On |
| Window previews | Show a live preview of the pointed-at or keyboard-selected window | On |
| Dark backing behind preview image | Add dark fill behind captured content | On |
| Fit preview frame to window proportions | Follow the captured window's aspect ratio | On |
| Window preview delay | Wait before showing a mouse-hover preview; keyboard selection is immediate | 400 ms |
| Popup animations | Animate opening, closing and expansion | On |

Both delays accept 0–2000 ms. Turning an option off keeps its saved values.
The keyboard opening shortcut still opens Search directly, regardless of the
double-click setting.

The **Panel and previews** section also contains **Dark backing behind preview
image**. Turn it off to expose the preview frame’s own background instead of the
dark inset; it does not remove dark areas that belong to the captured application.
**Fit preview to window proportions** is on by default. The card follows portrait
and landscape windows within the monitor’s size limit. Once the first captured
frame sets its proportions, the frame stays the same size until closed. If the
source window is resized, its live image fits inside that frame; reopening the
preview fits the new proportions. Turn it off for the previous fixed frame. The app icon and title remain above the image.

## Window list

| Control | What it changes | Default |
| --- | --- | --- |
| Show special workspaces | Include Scratchpad and other special workspaces | On |
| List density | Spacious or Compact rows, without reducing text size | Spacious |
| Springy scrolling | Add spring effects at the scroll boundaries | On |
| Mouse wheel speed | Adjust wheel scrolling from 50% to 300% | 102% |
| Shortcut numbers on the right | Align Ctrl number shortcuts in a right-hand column | Off |

The wheel setting applies to lists, Settings and selection menus. Pixel-based
touchpad scrolling keeps its native behavior. Shortcut numbers normally follow
the app/tab label; when aligned right, the Active label moves beside them.

## Personalization

This section contains background controls followed by **Text shadow**,
**Pictures and Gifs**, **Colors**, **Interface size**, **Bar label** and **Custom text**.

### Panel background

With **Wallpaper** selected, **Follow bar style** sits beside its default label.
It is on by default. It uses Solid while the bar is opaque and restores
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

### Text shadow

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

### Pictures and GIFs

Settings defaults to **Random GIF**: one of the 37 bundled Omarchy animations
is selected on each new opening. Hover keeps the original pixel-animated
Omarchy wordmark. Both use theme colors by default. Resizing and returning from a Settings submenu
keep the same GIF. This does not randomize colors, motion or opening effects.
In **Settings → Personalization → Pictures and Gifs**, choose
artwork separately for the compact panel and Settings. Changing or restoring one
leaves the other unchanged. Each has its own visibility switch.

#### Playback and cooldown

For animations, each view has a **Loop animation** switch and
**Delay loop** field. Looping is on by default; the pause between repetitions
defaults to 4.2 seconds. Enter whole or fractional seconds (`0.3` or `0,3`), then
press Enter or leave the field to save. Zero removes the extra pause. Switching
looping off plays once and holds a GIF's last frame. In Settings, returning from
a submenu resumes the same animation rather than replaying it; a new Settings
visit starts another playback if cooldown permits. The
saved delay stays available when looping is switched back on. **Cooldown** prevents
restarting the animation when reopening the panel too soon: enter seconds or
minutes, including fractions. During that interval the logo stays still. Each
logo keeps its own cooldown, starting when its last animated appearance ends.
The defaults are one minute for hover and zero for Settings; zero allows animation
on every opening. The timing reset arrows restore those values and the 4.2-second
loop delay, without changing the other logo.
Enable **Shared cooldown** to use one interval for both logos. Playing either
animation then delays both, even when they use different images. Turning sharing
off restores the separate cooldown values.
Animations stop while hidden.
The original pixel animation keeps the theme color and translucent wordmark,
with a passing pixel glint.

#### Choosing artwork

The **Pictures and Gifs** chooser includes the two original presets and 37
Omarchy animations. **Random GIF** enables random selection (the default in Settings);
**Next GIF** previews another candidate without saving it as a fixed choice.
Search by name, select a result to preview it, then choose
**Use this**. **Cancel** leaves the saved choice alone. Only one preview runs.
The library and file browser stay open when you click another application.
Use **Back**, **Cancel** or **Esc** to close them; your unfinished choice stays
available while you work elsewhere.
**Your files** opens the local file browser and remembers up to 12 applied files;
removing a recent entry never deletes the original. A missing file can be selected
again. GIF, PNG, JPG, WebP and SVG files remain in their original location.

#### Colors and effects

Choose **Use theme colors** or retain the image's original colors.
**Transparency** fades the artwork itself, including GIFs and the pixel wordmark,
independently for each view. Preview it before **Use this**; **Cancel** discards
the change. GIFs default to 50% transparency in both views; still images and the
pixel wordmark keep 100% of their own opacity, including the wordmark’s built-in translucency. Reset restores the source's default.
Manual values remain in effect when changing files or drawing another random GIF. Transparent pixels in files
stay transparent, and the original pixel wordmark retains its subtle base tint. **Motion** adds
an optional pulse, float, sway, spin or breathing effect to either a built-in
choice or your own artwork. Loop delay and cooldown keep their existing behavior.

**Opening effect** adds pixels, assembling fragments, a wipe, horizontal blinds,
a circular reveal or a fade to any image or GIF. **Replay** previews it;
**Use this** saves it for that view. It plays once per opening alongside the GIF
and optional Motion. Returning from a Settings submenu resumes the same effect.
Cooldown applies; **None** removes the effect without changing your file.
Software rendering uses a simple fade instead of the GPU patterns.

#### Moving, resizing and resetting

Use the visual editor to change size, proportions and position. In the main Settings view,
hold **Ctrl** over the artwork: drag inside its outline to move it, use the wheel
to resize proportionally, or drag the left/right handles to change width and the
top/bottom handles to change height.
Drag any corner dot to resize both dimensions together, keeping your current
proportions, including any custom stretch.
Controls and keyboard focus stay in Settings while Ctrl is held, even when the
pointer leaves the panel. Release Ctrl to leave editing mode.
Move a handle outward to enlarge the artwork, or inward to shrink it.
Resizing and zooming expand both sides equally while there is
room. At an edge, the artwork shifts only as far as needed to keep growing inside
the available area. Growth stops when that area is full, without shrinking the
other dimension. Shrinking stops at a small usable size so the handles remain
reachable.
Double-click either side handle to centre horizontally, or the top/bottom handle to centre
vertically within the artwork area. This keeps your width, height and zoom settings.
While holding Ctrl, double-click the picture itself to centre it on both axes,
keeping its size and proportions. The arrow on the visual editor resets placement.
The arrow beside the artwork chooser restores the complete default for that view:
pixel wordmark in hover or random GIF in Settings, 100% scale and proportions,
default position, theme colors,
effects and playback. It leaves the other view and original files unchanged.
Artwork stays inside the available decoration area and does not cover controls.

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
colors, brightness and field transparency. When saving or editing a preset, choose
**All themes** or **Only [theme]**. Its button shows that scope; the list contains
global presets and those for the current theme. Applying a preset uses its saved
scope. **WindowPeek pink** belongs to Tokyo Night. Older presets without a theme
association remain global; you can assign a theme when editing them.
Presets retain theme-following colors; existing single-color presets still work. Background mode, its main transparency slider, blur and grain
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
During slider dragging, pointer movement is measured in screen coordinates so
live panel resizing does not feed back into the selected value.
The editor grows to fit its controls and preview. Scrolling is needed only when
the available screen height is too small for the selected scale.

### Bar label

Choose the full label, compact label or name only. The default shows WindowPeek
and the window count. For your own wording, open Custom text.

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

## Controls

### Keyboard & mouse shortcuts

Change the opening shortcut, window selection and navigation keys, preview-hiding
modifier, and mouse modifiers for moving windows. The editor checks for conflicts,
lets you reset one action or the whole draft, and saves only with **Apply**.
Existing system bindings are not overwritten. Tab and Shift+Tab move between
controls, treating the window list as one stop; use arrows inside the list.

[Full keyboard guide](GUIDE.md#keyboard-controls)

### Updates

**Check now** checks for newer code. When available, **Update…** opens Omarchy's
terminal confirmation; **View changes** opens the comparison. Without an available
update, the second button is **Version history**.

- **Update notifications** checks for newer repository code and shows a notice.
  It is the same setting as **Automatic updates** in the footer.
- **Verified updates** installs only verified, immutable releases automatically.

Both start enabled and are independent. Manual updates can install code still
awaiting catalog verification. Development copies and local edits are protected.

[Update behavior, confirmation and schedules](UPDATES.md)

### Hints and Support

Read the controls for the window list, moving, keyboard navigation and Settings.
The examples follow your saved shortcuts. **?** in the footer toggles hints;
a new installation shows them automatically for the first 100 displays.

**Report Bugs or Post Your Ideas** opens the repository's Issues page.
**Troubleshooting** opens focus-protection choices and the history of suspected
interruptions, with controls for ignoring or restoring warnings. Protection starts
off and requires your explicit choice.

[Troubleshooting](TROUBLESHOOTING.md) · [Hints and saved preferences](GUIDE.md#hints-and-saved-preferences)

## Defaults

These values apply to a new installation. Updates keep saved choices; they do
not reset an existing setup. Missing preferences use the corresponding defaults.

| Setting | Default |
| --- | --- |
| Language | Automatic, following the system; 30 languages available |
| Open on hover / expand on double-click | Both on; a single bar click opens compact, a double-click opens Search |
| Allow pinning compact panel | On |
| Bar hover / window preview delay | 400 ms each |
| Window previews / dark backing / fit to proportions | All on |
| Popup animations / springy scrolling | Both on |
| List layout / special workspaces | Spacious / included |
| Mouse-wheel speed / shortcut numbers on the right | 102% / off |
| Panel background | Wallpaper |
| Wallpaper transparency | Starts at 70%; may be lowered once per theme for very poor contrast |
| Transparency-mode transparency | 8%, independently of Wallpaper |
| Grain / wallpaper blur / Follow bar style | On / off / on |
| Accent | Adapted: pink `#D898F5` in Tokyo Night, theme accent elsewhere |
| Color editing scope | Current theme |
| Panel scale / bar text scale | 100% each, following Omarchy at that scale |
| Bar label | WindowPeek and window count |
| Text shadow | Automatic |
| Hover artwork | Pixel-animated Omarchy wordmark, enabled |
| Settings artwork | Random bundled Omarchy GIF, enabled |
| Artwork colors / extra motion / opening effect | Theme colors / None / None in both views |
| GIF transparency | 50%; still images and the pixel wordmark keep their own opacity |
| Artwork zoom, width and height / offsets | 100% / centered (0, 0) |
| Animation looping / pause between loops | On / 4.2 seconds in both views |
| Hover / Settings cooldown | 1 minute / 0; shared cooldown off |
| Hints | Automatic for 100 displays; manually re-enabling removes the limit |
| Update notifications / verified automatic installation | Both on; independent settings |
| Keep search focus / temporary protection | Off; require an explicit choice |
| Header pin | Off on every new panel opening |

See [Updates](UPDATES.md) for the separate check and installation schedules,
and [Troubleshooting](TROUBLESHOOTING.md) for focus-protection trade-offs.

[Back to README](../README.md) · [User guide](GUIDE.md)
