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
| `Preferences.qml`, `Settings.js` | Atomic durable preferences and revision handling |
| `Appearance.js` and editors | Color rules, presets, preview, apply/cancel and scaling |
| `Labels.js`, `LabelsEditor.qml`, `LabelButton.qml` | Text templates, grouped editing and bounded action labels |
| `I18n.js` | Locale detection and 30 catalogs without changing Qt's global translator |
| `Updates.qml`, `update.py` | Shared daily schedule, verified immutable releases and atomic replacement |

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

Ctrl+1–9/0 uses the first ten window rows intersecting the current list viewport,
including search, special-workspace filtering and the opening active-window
promotion. Workspace headings do not count; each group tab has its own position.
`WindowList.visibleWindowAddresses()` supplies both the Ctrl hints beside the
app/tab labels and the key handler's targets. Scrolling recomputes their numbering.
Zero selects the tenth visible row. `ShortcutModifiers` samples both Ctrl keys
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
This routes Ctrl+digits to the list instead of the
application underneath. The expanded main list also handles these keys; modal menus, settings, busy
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
remain readable on the 200th display and stop on subsequent hovers.
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
the pointer or the card whose move menu is open. The latter retains its anchor,
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

`install.py` validates the manifest and copies selected runtime files, or links
the checkout for development. Replacement uses Linux atomic directory exchange.
It refuses to replace an unrelated installation. Removal targets only this
plugin and keeps preferences.

`Runtime.qml` owns one `Preferences` and `Updates` instance across monitors.
Panel edits and host settings both save to the durable preferences file before
publishing the result to widget instances. The host's inline entry is a mirror;
older revisions cannot overwrite a newer saved choice. Failed writes retain
the last saved UI values and permit a retry. Corrupt or unreadable files block
saving and updating until repaired and reloaded.

`Updates.qml` defers starting a worker while a panel, hover popup or window
operation is active. `update.py` owns the persistent 24-hour deadline and an
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
