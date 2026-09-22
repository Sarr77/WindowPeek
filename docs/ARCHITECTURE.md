# Architecture

WindowPeek is a QML plugin loaded by Omarchy. One runtime serves every bar
instance; no daemon or per-monitor compositor reader is needed.

```text
Hyprland events → WindowState → WindowModel → Widget / PanelContent
                       ↑                           |
                       └── WindowActions ←─────────┘
                                  |
                           WindowCommands → Hyprland Lua
```

## Responsibilities

| Module | Responsibility |
| --- | --- |
| `Runtime.qml` | Shared state, actions, preferences, theme and editor previews |
| `WindowState.qml`, `Compositor.js` | Read and validate compositor snapshots; coalesce events |
| `WindowModel.js` | Pure normalization, literal search and workspace grouping |
| `WindowListModel.js` | Stable presentation rows shared by search and hover |
| `WorkspaceHeader.qml` | Shared workspace labels, visibility markers, monitor alignment and section spacing |
| `WindowCommands.js` | Validated destinations and explicit Lua commands |
| `WindowActions.qml` | Serialize actions, refresh before acting and verify completion |
| `Widget.qml` | Bar label, monitor routing, settings synchronization and IPC |
| `Panel.qml`, `vendor/omarchy/WindowPanel.qml` | One rounded surface, hover expansion, focus lifecycle and screen bounds |
| `PanelContent.qml`, `WindowList.qml`, `WindowRow.qml` | Shared list, search, selection, distinct focus/move controls and settings |
| `SettingsContent.qml`, `SettingsSection.qml`, `SettingsRow.qml` | Grouped preferences, saved-state switches and editor navigation |
| `RowSurface.qml` | Shared window/Move borders, hover and press colors |
| `TooltipContent.qml`, `WindowPreview.js` | Settings preview and session ordering of the full inventory |
| `WindowIcon.qml` | Shared desktop-entry icon lookup and window-outline fallback |
| `WindowPreviewTarget.qml`, `WindowThumbnail.qml`, `WindowCapture.qml` | Row ownership, interactive preview card and on-demand window capture |
| `WindowClickArea.qml`, `MoveMenu.qml` | Modifier-aware clicks on passive surfaces and compact destination selection |
| `PreviewModifiers.qml` | Bounded Shift-state observation for preview privacy without keyboard focus |
| `ShortcutModifiers.qml` | Ctrl state on opening and while the window list is visible |
| `OpenShortcut.qml`, `OpenShortcut.js` | Register an unused Super+Alt+P chord for the enabled plugin |
| `Preferences.qml`, `Settings.js` | Atomic durable preferences and revision handling |
| `Appearance.js` and editors | Color rules, presets, preview, apply/cancel and scaling |
| `Labels.js`, `LabelsEditor.qml`, `LabelButton.qml` | Text templates, grouped editing and bounded action labels |
| `I18n.js` | Locale detection and 30 catalogs without changing Qt's global translator |
| `Updates.qml`, `update.py` | Shared six-hour schedule, verified immutable releases and atomic replacement |

## Inventory and identity

The reader calls `hyprctl -j --batch clients;workspaces;monitors;activewindow`.
A batch reduces process overhead and keeps the observations close together; it
is not a compositor transaction. Relevant events are coalesced for 40 ms, with
a 5-second reconciliation read. A failed or timed-out read invalidates the
snapshot instead of displaying stale data as current.

`normalize(snapshot)` returns `{status, windows}`. Missing client data means
`unavailable`; an empty array means a ready desktop with no windows. Each
window has `address`, `app`, `appId`, `title`, `workspace`, `group`, `hidden` and
`active`. Desktop entries supply display names and icons where available;
classes remain the fallback.

Addresses are validated, nonzero hexadecimal strings. They never pass through
JavaScript numbers. Duplicate titles remain separate results; duplicate
addresses keep the first mapped record. Hidden group members remain ordinary
records. Workspace and monitor metadata are matched against the current
snapshot, with explicit unknown placement when metadata is incomplete.

`search(inventory, query, {includeSpecial})` returns `{status, sections}`. It
matches a literal fragment of application or title, ignoring case and outer
whitespace, and normalizes Unicode to NFC. Accents remain significant. Section
order is numbered, named, special, then unknown workspaces; row order is by
address. Title and focus changes therefore do not rearrange the list.

The full inventory retains special workspaces. The UI passes its persisted
`includeSpecial` choice, which defaults to true. Explicit saved choices take
precedence over the default. The bar count uses the same
filter. Normalization and search do not mutate their inputs.

## Selection and actions

Keyboard selection is an address, not a row index. If the selected window
closes, selection clears. Enter cannot silently operate on its replacement.
Mouse controls capture the address at press time. Focus and Move have separate
hit targets, keyboard focus and accessible labels.
Left/Right follow their physical column positions, mirrored in RTL; Up/Down
preserve the action column and reveal the next window across workspace headings.
At the search text edge, the arrow toward Move transfers focus into that column.
Cursor movement and text selection inside the search field retain their normal behavior.

IPC open/toggle and the automatic Super+Alt+P binding request quick selection.
After the expanded controller's bindings settle, PanelContent starts a five-second
timer. The existing visible-row numbers and digit mapping also accept unmodified
keys during this interval, including Num Lock-off keypad navigation keysyms.
Physical Ctrl state is unchanged. Text editing, collapse, closing or leaving the
available window list cancels the timer. Ordinary mouse opening does not start it.
Page Up/Down scroll a viewport and select a visible row; Home/End select an endpoint.
Row actions retain their column. Home/End in a nonempty search keep text editing.

Only the widget owning IPC registers the default opening shortcut. It first reads
`hyprctl -j binds`, preserving existing chords. Its private Lua handle is reused
and disabled on teardown, with a 15-second compositor expiry renewed every five
seconds in case the shell dies. Config reload rechecks conflicts. No config files
are changed and user bindings are never unbound.

Ctrl+1–9/0 uses the first ten window rows intersecting the current list viewport,
including search, special-workspace filtering and the opening active-window
promotion. Workspace headings do not count; each group tab has its own position.
`WindowList.visibleWindowAddresses()` supplies both the Ctrl hints beside the
app/tab labels and the key handler's targets. Scrolling recomputes their numbering.
Zero selects the tenth visible row. `ShortcutBindings.js` leases Ctrl+digits and
physical numpad digits to the visible main list through Hyprland. This catches
fast chords before the asynchronous Ctrl focus request reaches the compositor,
so the digit cannot reach the application underneath. The event carries the
current opening's token; stale events and events outside the main list are ignored.
The ordinary Qt handler remains available for focused events and offline tests.
Closing, settings, menus and busy actions disable only the plugin's binding
handles. Handles are reused, without editing config files or unbinding user keys.
A compositor timer disables them after 750 ms without renewal, including when
the shell terminates unexpectedly. Bindings do not repeat or run through a lock.
`ShortcutModifiers` samples both Ctrl keys
on opening and every 50 ms while a main list is available, with one outstanding
request, a per-instance token and a 250 ms timeout. Focused Qt key events update
the state immediately and invalidate older pending samples. Closing, settings,
menus and busy actions stop observation and clear the hints.
Hover temporarily requests keyboard focus while Ctrl is known to be held, without
expanding, changing its input mask or registering a full bar popout. Releasing Ctrl
returns keyboard ownership. Without a preview, Ctrl keeps exclusive keyboard
focus instead of dropping to OnDemand after the normal opening delay. A visible
preview uses OnDemand so its pointer events remain available. The list first
primes keyboard focus unless the pointer is already on the preview. The preview
forwards key events to the source list's locally focused control when its XDG
popup receives the keyboard. Local focus follows search and row navigation even
while the source window is inactive; hover forwards directly to the list.
Held Ctrl also retains the hover: claiming the keyboard may remove the bar's
pointer hover, which must not trigger a close/reopen loop under a stationary cursor.
The expanded main list also handles these keys; modal menus, settings, busy
actions and auto-repeat cannot start another action. The chosen row's address
uses the same validated focus and panel-unmap path as a plain click.
`shortcutNumbersRight` is a persisted boolean, false by default. It places the
second-line number at the physical right edge and reserves room to its left for
the active label. Both positions reserve space before eliding the app/tab label.

An action refreshes state before building a command. Only one action may run
at a time. Hyprland receives the validated address through an argument vector;
titles and application names never enter commands. A move validates the source
workspace and destination, refuses a locked group and detaches only the target
member before a silent move. Names are quoted separately from Lua syntax.

Before focusing a special-workspace window, select its existing monitor using
the live window object. Hyprland's window-focus dispatcher otherwise summons
the whole special workspace onto the currently focused monitor.

Ctrl+click opens `MoveMenu` at the pointer position in a transient overlay layer.
`chooseDestination` retains any visible preview before mapping the menu, whether
invoked from a row or the preview card, preserving its anchor and capture.
It owns keyboard focus and an outside-click shield while visible; the main panel
temporarily releases keyboard ownership without changing its mode, dimensions
or scroll position. This places the menu above a retained native preview popup.
For a retained animated preview, the menu renders in its own XDG popup anchored
to that overlay: Hyprland draws XDG popups after all layer surfaces, so a layer
alone can receive input while remaining visually obscured. Instant layer
previews keep the layer menu. The popup waits for its parent layer to be mapped
with a positive size; zero-sized XDG positioners disconnect the Wayland client.
The menu retains its popup host until closing if
animations change while it is open. The panel retains hover until the menu closes. The menu and its backdrop consume unhandled wheel events,
including list boundaries, so scrolling cannot reach the window list underneath.
Choosing a destination uses the existing validated move
action; errors leave the menu available for retry. Scratchpad is a fixed footer
action, excluded from filtered rows. The Move button retains the full form.
Preview clicks translate their position into the monitor-local scene. Panel
release callbacks wait for both its main surface and the menu to unmap.

`BackMouseArea` consumes only secondary clicks and passes wheel events through.
Settings and editors route it to their existing Back/cancel path; each dropdown,
move menu and update confirmation closes itself. Primary clicks and hover remain
owned by the controls underneath. On the main list, a secondary click follows
the panel's complete dismissal path, including its preview, in either list mode.

`WindowClickArea` captures the address and position on press. Focused surfaces use
Qt modifiers. Passive surfaces request a fresh Ctrl/Shift sample from Hyprland,
independently of preview preferences. A matching reply and a completed click are
both required; cancellation, timeout, disabled controls or a replaced target
invalidate the request. No additional polling or keyboard grab is used to detect
the gesture. This avoids assuming keyboard state on an unfocused Wayland surface
([modifier delivery](https://wayland.freedesktop.org/docs/html/apa.html#protocol-spec-wl_keyboard)).

Ctrl+Shift+click uses a separate `bring` action in both views. Its destination is the
active ordinary workspace on the invoking widget's screen, not the globally
focused monitor. A fresh snapshot captures the destination before panel unmap;
the Lua command rechecks the monitor and active workspace before detaching or
moving anything. A changed destination fails without retargeting. The selected
window moves silently and is then focused; completion requires the workspace,
monitor and active address to match. Already-present windows are focused without
detaching their group. Locked groups retain the existing refusal behavior.

Command acceptance does not count as completion. Subsequent snapshots must
show the requested active address or destination workspace. Actions have a
3-second deadline and never retry mutations. Errors are localized and contain
no window titles. Focus and bring wait for the native panel surface to unmap before dispatch; failures
reopen it with the error. Ordinary dismissal relies on layer-shell focus
restoration, repairing missing focus only when no application has taken it.

The implementation uses the installed Hyprland 0.56.2 Lua API. Native tests
cover hidden tabs, locked groups, named and special workspaces, and monitors.
Older Hyprland configurations without Lua can display the inventory but cannot
perform these operations.

## Presentation and settings

`WindowList.fittedHeight()` measures delegate positions and ends the opening
viewport at a window row near the preferred 420-unit height. The native surface
passes its available height after borders, padding and UI scale; headers and
footer are then subtracted. When the next row will not fit, the previous complete
window becomes the boundary. `contentY` is not a sizing input, so scrolling keeps
the surface stationary. Native height rounds upward to avoid clipping a border
at fractional scales.

`SettingsContent` owns the preference controls and picker lifecycle; `PanelContent`
retains navigation, scrolling and editor preview ownership. Switches and density
bind to saved state and never confirm a failed write. Editor return restores the
settings scroll position, expanded category and entry focus. `SettingsSection`
owns its collapsed state and a keyboard-accessible outlined header. Hidden contents
remain instantiated but cannot receive pointer or Tab input; collapsing closes
open pickers. Expansion settles the inner and outer layouts and only reveals the
header if needed; it never scrolls to fit the whole category. This UI state is not
written to preferences. Settings requests a fixed 640 logical pixels, capped by
the native surface's available monitor area, with a scrollable interior.
Switch tracks use the resolved accent directly, including theme-specific Colors
rules, while their knob position distinguishes the saved on/off state.
`ControlsHelp` renders the mouse and keyboard guide from the selected language
catalog, independently of custom action labels. It uses the settings scroll view
and does not write preferences. The documented system shortcut requires a user binding.
Color drafts contain only color rules
and presets, so applying one cannot overwrite newer density or scaling choices.
Stored preference names are unchanged.

`DefaultValue` presents a translated default and an optional `ResetButton`. The
compact ↺ action sits beside numeric controls, with a translated tooltip and
accessible name. It emits a request without changing state itself. Delay controls use the durable
save path; color, scale and text controls reset only their editor draft. The
color reset targets the displayed scope and preserves presets and other theme
rules. Text resets clear a single override so it follows the current language.
Switches and simple selectors display their defaults without additional actions.

Both dropdown types exclude their parent trigger from press-outside dismissal.
The trigger toggles `visible`, so a press cannot close the popup and reopen it
on release, including during rapid clicks or transitions.
The searchable popup positions its search header and result list inside a column;
the secondary-click overlay is their sibling, outside that layout. This keeps
the overlay's fill anchors from disabling the column's positioning.

`WindowPanel` adapts Omarchy's `KeyboardPanel` focus acquisition, bar coordination
and outside-click dismissal. It retains the upstream layer namespace so Omarchy
disables compositor animations around the QML transition. Hover and search share one mapped layer surface,
rounded card and list. Hover accepts pointer input inside the card and the transparent gap to the bar,
has no keyboard focus and creates no dismissal surfaces on other monitors.
The gap follows the adjoining card edge for every bar position and shares the
same native input mask. A stationary pointer there retains hover; clicks have
no action. The region stops at the bar edge, leaving bar buttons reachable. `Widget` applies
the configured opening delay (400 ms by default) only to a new hover session; returning to its label
retains an already open hover immediately, ahead of the 160 ms leave timer. Clicking the
bar expands its width from 420 (360 in compact density) to 500 over 200 ms,
revealing search, Move, Settings and footer controls. The card does not fade or
remap during that transition. Its opening origin is retained where screen bounds
allow, and rows keep their identity, order and scroll offset. Search receives a
brief exclusive keyboard focus prime before switching to on-demand focus.
Direct opening starts expanded. Only expanded mode owns the bar coordinator and
outside-click regions. Panel dimensions are clamped to the screen before
scaling; long lists and editors scroll within fixed header/footer bounds.
Rapid reopening waits for the old layer surface to unmap, so its closing
animation cannot leave a visible panel without keyboard focus. Dropdown
placement accounts for the same transform. Application text is always
plain text. Arabic enables layout mirroring.

Window entries and Move controls share a subtle resting border, an accent hover
border and a stronger pressed fill. Transitions take 120 ms; the one-pixel
border and control geometry remain constant. An accent stripe marks the active
window independently of pointer hover and keyboard selection. Colors follow the
popup palette and WindowPeek's existing accent preference in both views.

The shared `WindowList` uses a persistent ListModel. `WindowListModel` matches rows by
workspace key or window address, applies changed roles and inserts, moves or
removes only affected rows. Routine title updates preserve the hovered control
and wheel animation. Opening a new session resets scrolling; expanding an existing hover preserves
it. Closing cancels any remaining wheel animation.
The list uses a Column inside a Flickable so the content height is exact.
Their scrollbars sit halfway between the rows and the panel edge, outside the
list's clip. Both lists reserve the same extra width when a scrollbar is visible,
so the search panel's Move controls have the same edge spacing as overview rows.
ListView estimates mixed row heights from its current delegates, which made the
scrollbar change size as workspace headers entered and left the cache. Creating
all rows trades virtualization for stable geometry; the preview already uses
this layout and the model is the desktop window inventory.

The `scrollBounce` preference defaults to true for both window lists. When enabled it uses
Qt's native `DragAndOvershootBounds` behavior, matching ScratchPeek's list
without a custom rebound animation. Disabling it selects `StopAtBounds` and
settles any active overshoot. Editor and picker scrolling stays bounded.

Row hover remains active during wheel scrolling, inertia and thumb dragging.
The window under the pointer keeps its accent frame and color transition.
Hints are passive surfaces in the same window, outside the list's clip. Unlike
Qt Quick popups, they do not intercept hover, wheel or clicks over nearby rows.
Their position follows the anchor's transform, including scrolling and scaling,
and stays within the window. Hints close when leaving the control or dismissing
the panel; display counting and the 400 ms dwell delay remain unchanged.
The scrollbar currently keeps a constant idle/hover thumb opacity during input
diagnosis; pressing it still increases the contrast. Its activity state does not
control row highlighting. The window lists align scroll offsets to pixels to
keep their one-pixel borders from moving through fractional pixel positions.
The fill retains its 120 ms color transition. Two passive outline items with
fixed colors crossfade through opacity over 120 ms. This avoids animating the
fill rectangle's border color, which flickered during wheel scrolling in a
visual comparison. The outlines remain in the same scene; there is no Canvas,
offscreen texture or separate render thread. Selection keeps the accent outline
fully visible, and input handling does not depend on animation or scroll state.

Compact and spacious density apply to both lists. Compact rows retain their two
text lines and font sizes. The persisted `tooltipStyle` key remains compatible
with existing preferences; the setting is labeled List density. Workspace labels
are formatted through `I18n.workspaceTitle` for both headers and destination choices;
destination identifiers stay unchanged. Headers reserve separate space for the
“Hidden” marker and monitor, with mirrored alignment in Arabic. The marker appears
only for workspaces absent from every enabled monitor's active and special
workspace. Unknown workspace identity or unavailable monitor data gets no marker.
The scratchpad has its own display label. Other special workspaces use a localized
label around the user's name, without exposing Hyprland's `special:` prefix.

The move form shows the source from the current inventory. A scratchpad shortcut
sits in the main form above the destination dropdown. That action uses the existing
move controller and verification; scratchpad is also a valid destination before
the workspace exists. Hiding special inventory does not disable this explicit
action. The form reserves space for the open dropdown and shrinks when it closes.
Scrollbars reparented outside their clips also follow their owning view's visibility.

Appearance, scale and label editors load only when selected. Appearance edits
preview through the shared runtime and commit only on Apply.
The owning widget object identifies the preview, independently of monitor names.
Cancel, Back, panel dismissal and owner destruction restore saved appearance;
another widget cannot cancel it. Back from an editor returns to Settings.
Tab navigation reveals the focused control within its scrollable view.
The bar tooltip uses the
same style and scale as its preview. Automatic hints count actual displays,
remain readable on the 100th display and stop on subsequent hovers.
Hover hints never consume Escape or take keyboard focus. Manual
on/off and the help explanation remain available independently of that budget.

The bar preview uses the same filtered inventory as search, with no row or
workspace limit. Its pure arrangement places the opening active window first in both modes.
That address stays fixed for the session so live focus changes cannot reorder it. A height-bounded Flickable and scrollbar keep every row
reachable at larger scales. App titles are primary; app names, grouped-tab
labels and monitor names provide context.
The popup opens without taking keyboard focus and remains open while the pointer
crosses onto its content or drags its scrollbar. It closes after a short leave
delay. Clicking a row captures its address and uses the same action controller
as search; focus dispatch waits for both native surfaces to unmap. Failed actions
reopen search with the error. Opening another panel dismisses the hover immediately.
Window information remains available after the hint budget expires; only its
help footer participates in the automatic display count.

Text customization uses `labelStyle` (`default` or `custom`) and `customLabels`.
`Labels.js` defines 28 editable fields in five groups and overlays their values
on the current language catalog. Missing or blank fields use translated defaults;
switching to default mode retains the inactive custom map. The existing bar-label
style supplies the fallback when no custom bar text is set.

Fields are bounded to 160 characters and normalized to single-line plain text.
Only declared variables are accepted: `{count}` and `{monitor}` on the bar,
`{count}` on the count badge, `{name}` in workspace labels, and `{workspace}` in
the move-source label. Substitution is single-pass; variable values are not
interpreted again. Invalid variables prevent Apply and fall back to the default
in runtime rendering. These strings never become compositor identifiers or code.
Long action captions elide inside bounded controls, keeping their accessible name.

The labels editor holds the raw draft locally to preserve the insertion point
while typing. A normalized preview is shared through Runtime, with its owning
widget object. Only that owner can clear it. Apply persists through the existing
preferences path; Cancel, Back, dismissal and widget destruction release the
preview. A failed save keeps the draft available. Editor controls use the base
translation catalog so editing action labels does not rename the editor itself.

The durable preference file is authoritative over stale bar entries. Each save
merges a revision, writes atomically and then synchronizes monitor instances
and Omarchy's inline entry. Corrupt data is reported and never silently replaced.
Failed writes preserve the last successfully saved values. Disabling or
reinstalling the widget does not remove the independent preference directory.

## Window thumbnails

Each widget owns one `WindowThumbnail`, shared by the collapsed and expanded list. A row requests
it after hover begins. An old row's leave event cannot close a newer row's
preview. The default 400 ms dwell avoids opening cards while the pointer passes over
entries. The popup is anchored to explicit visible-card bounds, not its native
window's size: WindowPanel uses a full-screen layer with a smaller
card inside. Mapping uses the actual `Window.window.contentItem` scene root;
WindowPanel's public `contentItem` is an alias to a child list.
The bounds item is the content's ancestor, including the panel padding. It must
not be a sibling overlay: Qt hover delivery visits one child branch and then
its ancestors, so a hovered overlay can exclude the rows even with
`HoverHandler.blocking: false`.

The popup flips at screen edges and follows the row during scrolling. Its top
is clamped to the visible parent card's top. It has
no keyboard grab; its own pointer region makes the preview clickable. Nonblocking
hover tracking retains it over the list or preview. Transparent side strips in
the preview's native surface cover the visible gap, including after horizontal
flipping. A stationary pointer there keeps both surfaces open without a timeout;
the strips do not activate a window when clicked. The row remains highlighted
over this area and the preview. That visual hover is separate from the row's
pointer request, so it cannot keep itself alive after the pointer leaves.
The 300 ms leave delay applies only outside the connected surfaces. The collapsed
parent also stays open while its child preview is visible.
Closing the parent, leaving the window list or removing the row dismisses the preview.
Expanding hover retains its row and preview owner.
Click, Ctrl+click and Ctrl+Shift+click capture the pressed address and use the same widget actions
as rows. Focus dispatch waits for the parent and thumbnail surfaces to unmap.

`WindowCapture` matches the inventory address to `Hyprland.toplevels` and passes
its Wayland toplevel to Quickshell's `ScreencopyView`. Capture starts only after
the preview surface maps. Frames stay in memory; destroying the loader releases
the capture context on close. Live mode queues the next frame through Quickshell
instead of polling single frames on a timer. Delaying those requests can leave
the last source repaint uncaptured. There is no fixed frame-rate cap: delivery
follows the compositor while the preview is visible. The view preserves aspect ratio and omits the pointer. No capture
path calls a focus, workspace or window-movement dispatcher.

Hidden windows and inactive group members can supply their own surface buffers.
An application that stops repainting while hidden can show its last frame.
Missing or unavailable capture gets localized placeholder text; there is no
fallback to capturing the entire monitor. The title wraps to at most two lines
and elides at the end of the second. The header grows to fit those lines.
Action instructions use the search row's passive `PanelHint` and its existing
hint budget. The preview has no instruction footer and does not consume that
budget; its title and image remain available when hints are off.

Holding Shift suppresses previews, with an exception for the preview card under
the pointer or a card retained while the move menu is open. The latter retains its anchor,
address and capture, ignores other row hover requests, and releases retention when
the menu closes. It still respects disabled previews and busy window actions.
`WindowThumbnail` retains the hovered row while suppressed, cancels
the dwell and unloads capture immediately. Release uses the configured preview delay again.
Outside the menu, the card's MouseArea determines the exception, excluding the transparent bridge.
Existing click handlers continue to read the click's modifiers independently.

The durable `windowPreviews` preference defaults to true and is shared across
widgets through the existing preferences path. It gates thumbnail availability,
so disabling it closes the card, unloads capture and stops modifier observation,
including while the pointer is on the card. Row ownership is retained while
hovered; reenabling starts a fresh modifier sample and normal dwell. The setting
does not alter row hints or click handlers.

`panelHoverDelay` and `previewHoverDelay` are independent persisted millisecond
values, normalized to 0–2000 with a 400 ms fallback for missing or malformed
values. Zero bypasses the opening timer. Changing a pending delay restarts the
wait or opens immediately for zero; an already open surface stays open.
The 160/300 ms leave grace periods are independent and retain pointer handoff.
`PopupMotion` uses a standalone NumberAnimation for panel opacity and size, so
disabling motion can stop it and set its target value synchronously.
`popupAnimations` defaults to true. Disabling it completes in-flight panel fades
and expansion, then bypasses subsequent animations without changing native
unmap callbacks, rounded borders or row feedback. Thumbnails share one card and
capture loader across two native surface types: the usual XDG popup when animated,
and `InstantPreviewSurface` when animations are off. The latter uses Omarchy's
existing unanimated layer role, with no keyboard focus or exclusive zone. It
places the card beside the parent, flips at the screen edge and preserves both
gap strips. This avoids Hyprland's separate XDG-popup fade without changing global
animation settings. The layer is loaded only when needed and released with its
owner; capture still requires a mapped, allowed preview.
Even at zero delay, a thumbnail waits for a known Shift state before revealing
content; its first captured frame still depends on the compositor and source.

`PreviewModifiers` reads both Shift keys through Hyprland's `hl.is_key_down`.
It queries only while a preview has an available owner, at 50 ms intervals,
using Quickshell's asynchronous IPC with at most one request outstanding.
A per-instance token and sequence match each reply; inactive and late replies
are ignored. Unknown state or a 250 ms timeout suppresses previews until a fresh
sample arrives. No subprocesses, keybindings, input grabs or configuration hooks
are created. The query emits only a boolean in a namespaced custom IPC event.
This also covers a stationary pointer over an unfocused hover panel: Hyprland
[sends keyboard modifiers to the keyboard-focused client](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/managers/SeatManager.cpp),
so observing Qt key events alone would miss that case.

API reference: [ScreencopyView](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/ScreencopyView/).

## Installation and updates

Installation and removal use Omarchy's standard `plugin add` and `plugin remove`
commands. The public source and release archive contain no separate installer.
WindowPeek stores preferences outside the plugin directory so they survive
removal and reinstall.

`Runtime.qml` owns one `Preferences` and `Updates` instance across monitors.
Panel edits and host settings both save to the durable preferences file before
publishing the result to widget instances. The host's inline entry is a mirror;
older revisions cannot overwrite a newer saved choice. Failed writes retain
the last saved UI values and permit a retry. Corrupt or unreadable files block
saving and updating until repaired and reloaded.

`Updates.qml` defers starting a worker while a panel, hover popup or window
operation is active. Each widget's minute timer shares the runtime scheduler.
The first eligible tick can request the day's first check via `--startup`;
later ticks follow six hours from `lastCheck`. The worker rechecks the same
local-calendar condition under its lock, preventing duplicate requests across
restarts or monitors. Valid `lastCheck` migrates old 24-hour deadlines to six hours.
Attempts, including failures, are recorded before network access.
`update.py` owns the persistent deadline and an
interprocess lock under WindowPeek's state directory. It uses fixed WindowPeek
endpoints, independently checks GitHub release immutability and the official
catalog's exact approved SHA, then verifies a fresh staged checkout. The tag,
authorities, saved opt-in and installed bytes are checked again before atomic
directory exchange. No cached approval or default-branch fallback is used.

A successful update restarts the Omarchy shell: a plugin rescan alone can retain
old QML components and singletons. Reload failure is recorded separately as
`restart-pending`. See [UPDATES.md](UPDATES.md) for the trust contract, skip rules
and filesystem limits. The real public update test follows publication.

See [TESTING.md](TESTING.md) for executable checks and their limits.

## Panel backgrounds

`panelStyle` selects `solid`, `wallpaper` (the default) or `glass` (displayed as
Transparency). Missing values use Wallpaper; malformed saved values fall back
to Solid. `glassTransparency` and
`wallpaperTransparency` are independent percentages, defaulting to 8 and 70.
The latter is the legacy/global starting value. `wallpaperThemeTransparencies`
stores `{value, defaultValue}` by theme: manual changes update only `value`, and
reset restores that theme's `defaultValue`. Missing entries retain the old setting.
The main panel's `WallpaperContrast` samples the first loaded wallpaper crop
before its opening animation. `wallpaper_contrast.py` downsamples the local image
through ImageMagick (an Omarchy base package); it does not capture desktop pixels.
Correction requires median full-text contrast below 2.5 and at least a quarter of
samples below 2. It then lowers transparency until the tenth-percentile contrast
for 65%-opacity descriptions reaches 4.5, or the palette's opaque limit. This
conservative trigger deliberately leaves imperfect but acceptable images alone;
it is not a claim of accessibility conformance for all labels or backgrounds.
Both adjusted and unchanged defaults are saved once per theme. Manual edits,
theme changes and the other monitor's completed result invalidate pending work.
Because Omarchy publishes the theme name before applying its palette, the helper
checks the requested name, base colors and theme shell roles against the current
theme files before and after sampling. A mismatch retries within the opening
deadline. Live text, tint or palette changes invalidate an in-flight result.
This prevents an outgoing dark theme's pale text from lowering the saved default
of an incoming light theme. Manual slider changes remain scoped to that theme.
Missing files, helper failures and save failures preserve the old value; a bounded
deadline releases opening. Later wallpaper changes do not override saved defaults.
`backgroundBlur` defaults to false and `backgroundTexture` to true. Preferences are shared
between monitors and survive restarts. Alpha affects background fills only.
`RowSurface` retains a theme-colored fill; child text and icons are unaffected.

`Runtime.wallpaper` observes Omarchy’s
`$HOME/.local/state/omarchy/current/background` link while any wallpaper panel
or thumbnail is open. A one-second `stat` probe detects symlink changes and
in-place edits. Its signature invalidates Qt’s image cache. There is no polling
with no consumers. This uses the same fixed path as Omarchy’s background plugin,
independently of the plugin’s XDG state directory.

`WallpaperBackdrop` reproduces Omarchy’s centered `PreserveAspectCrop` fit for
each monitor, translated into the card’s local coordinates. Rounded clipping
keeps the image inside the card. Its backing stays opaque while loading or if
the file is missing, so applications behind it cannot leak through. The slider
controls the theme tint over this image. Optional Qt Quick blur samples the
surrounding wallpaper pixels; a small tiled SVG supplies subtle grain. Neither
effect changes global compositor settings or captures the desktop.

The main card starts its opening animation only after the wallpaper lookup and
image load have settled. A missing or unreadable image opens with the opaque
fallback. Readiness is latched for that opening so refreshing the wallpaper does
not fade out a panel in use, and closing can finish without waiting for the image.
Image replacement retains the previous pixels during loading. A lookup from an
earlier observation session cannot release a newer opening prematurely.

`WindowPanel` and both thumbnail surfaces request `BackgroundEffect.blurRegion`
only in Transparency mode and only for their rounded card, excluding transparent
dismissal and pointer bridges. The request is removed in other modes or when the
surface closes. The
[Quickshell background effect](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/BackgroundEffect/)
uses the compositor’s `ext-background-effect-v1` support and respects its blur
setting; no global layer rules are needed. Without compositor blur, the theme
tint and translucent row backgrounds still render.

## Background view switching

`Panel.toggleExpanded()` shares the normal `Widget.open()` path for promotion.
Demotion retains the mapped card before releasing the panel controller, keyboard
focus and bar ownership. It keeps row objects and unfiltered scroll, clears a
search filter, and avoids the close/action lifecycle. Rounded borders and opacity
remain unchanged during the size transition. Settings, move forms, confirmation
and active drags block this gesture.

The card's background MouseArea sits behind its controls. A separate background
area in the Flickable receives headings and gaps; normal row actions remain above
it. Wheel events pass to the Flickable, which can also steal a background press
for dragging. Only unmodified left clicks toggle the view.

`openOnHover` defaults to true and uses the shared durable preferences. Turning it
off cancels bar hover eligibility, dismisses a passive panel and prevents demotion;
bar clicks and the shortcut still open the expanded view. The bar-delay setting
is disabled while hover opening is off. Thumbnail previews have their own switch.

Closing through the bar label latches a per-widget hover dismissal before closing
its controller. This cancels any dwell, including zero-delay opening. Leaving the
label releases the latch; explicit clicks and the keyboard shortcut remain usable.
The latch is session state and is never written to preferences.

The Settings wordmark is decorative and takes no input. It is fixed near the
bottom of the viewport and clipped to the space below the settings content.
Expanding or scrolling sections covers it without moving headers or adding
scrollable space. It is hidden in the window list and all editors.


## Surface colors and presets

`SurfacePalette` resolves panel tint, window fields, menu fields and grain from
`Appearance.surfaceColors`. Each role has an independent theme/all scope,
a global rule and keyed theme rules. Rules hold optional RGB, brightness
(-100–100) and opacity (0–100 or null for the native default). Missing rules
preserve the original theme styling. Wallpaper brightness uses Qt MultiEffect;
RGB fills mix toward white or black. Grain colorization uses a monochrome copy
of the original SVG mask, leaving the default two-tone texture intact.
Theme colors are converted to opaque RGB before entering the color editor;
Qt's `#AARRGGBB` serialization must not be passed to RGB-only normalization.
An unmodified Solid panel retains the theme's original alpha. Wallpaper and
Transparency use their own transparency settings over the theme's RGB tint.

New entries in `colorPresets` include a normalized `style` snapshot of the accent
and all surface roles. Older color-only entries are still accepted. Applying a
snapshot writes each role to the selected scope; resetting uses default rules
without deleting unrelated themes or the preset library. The existing shared
preview owner and atomic preferences path handle Apply/Cancel and save failures.
Background mode, per-theme Wallpaper transparency, the shared Transparency
percentage and effect switches stay
independent of color presets. `AppearancePreview` demonstrates both backdrop modes
and observes wallpaper only while mounted and visible.
Its overlay selects appearance roles using the actual sample/row geometry,
including RTL, clipping and scale. Sample window actions stay disabled. Picking
a role calls the same draft-preserving selector as the dropdown without requesting
a scroll. The sample precedes the controls whose visibility changes by role.
Passive outlines attach to the selected sample items, inheriting their geometry
and clipping. The outline uses the current interface accent over a thin theme
background edge. The preview caption follows the selected role, not hover.
Initial focus stays at the editor heading rather than revealing HEX below the
sample; keyboard navigation still reveals focused controls. Wheel events continue
to the parent scroll area. Colors and Interface size entries use a resting accent
border and chevron to distinguish them from inline settings.
Dropdown popovers share `DropdownSurface`. Wallpaper paints the same desktop
crop at the popup's window coordinates over an opaque backing; a minimum 40%
theme tint keeps text readable without showing controls underneath. Drawing in
unscaled window pixels preserves crop and blur/grain density at every UI scale.
Transparency uses `SurfacePalette.pickerBackground`, mixing a little menu color
into the panel tint with 94% coverage. Solid keeps its native surface; trigger
rows, text and focus styling remain native.

The footer and status use `Runtime.version`, checked against the manifest. Both
native-card and list-background input paths accept unmodified middle clicks to
toggle the hover/search view through the existing guarded transition.


`previewBackdrop` controls only the inset behind captured content. It defaults
true; disabling it removes the dark fill and inset border, leaving the card’s
chosen Solid/Wallpaper/Transparency background. `previewFit`, also true by
default, fits the image using the capture’s raw sourceSize within a bounded
290 × 300 logical-pixel content area (subject to theme metrics and screen size).
Unknown sources and the opt-out use the previous 290 × 164 content area. Padding
and the title sit outside the image, so portrait previews do not inherit a
landscape viewport. No capture dimensions depend on their displayed dimensions.

The first valid captured sourceSize is latched for each opening. A source resize
updates live pixels within the existing area without moving the card or click
target; the next opening measures again. Two title lines are always reserved
so a live title update does not resize the frame either. The cached ratio can
still be constrained by a changed monitor or UI scale.

## Editable action shortcuts

`Shortcuts.js` defines canonical chords and resolves saved preferences. Invalid
or conflicting external data falls back to the defaults. `ShortcutsEditor` keeps
a separate draft, rechecks Hyprland bindings before Apply and persists through
the existing atomic settings path. It does not touch compositor config files.
`ShortcutRecorder` is a modal, stable-size popup; its `ShortcutInhibitor` targets
the Quickshell proxy window and accepts recorded chords only while inhibition
is active. Closing, cancelling or unloading the popup releases inhibition.
Mouse composition remains available without compositor support.

The number modifier is shared by Qt handling, held-state polling and the leased
Hyprland digit bindings. Modifier families reuse their own handles and disable
previous families when switching. The opener similarly leases its chosen chord
only when unused. Existing manual bindings are preserved. Preview suppression
and both row/thumbnail click paths read the same configuration. Ordinary field
editing and standard control activation stay independent of these action keys.
