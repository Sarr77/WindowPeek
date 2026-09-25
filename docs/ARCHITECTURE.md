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
`PanelContent.compactKeyBindings` prepares hover key definitions when shortcut
settings or text direction change. Expand/collapse only selects that prepared
array or an empty one. Rebuilding and revalidating all chords during every
collapse added several milliseconds before the resize animation could proceed.
`HoverBindings.js` leases the configured navigation/action keys only while a
compact main list owns native keyboard focus. It shares the digit lease's session
token and 750 ms expiry, reuses private handles, and releases them on focus loss,
close or promotion so background applications retain their navigation keys.
Keypad navigation aliases never override the configured modifier's ordinal keys.
Tab and side actions promote via the host widget to preserve its focus lifecycle.

`selectedPanelStyle` retains the stored choice. Opt-in `followBarStyle` resolves
Wallpaper to Solid only when the invoking `PluginBarApi.transparent` is false;
unknown bar state preserves Wallpaper. The effective `panelStyle` feeds all
surfaces. Settings edits still target the selected style, without saving any bar
state changes or altering Wallpaper appearance values.

`PanelLogo` replaces the expanded search/footer space and uses the same translucent
accent in Settings. `hoverLogoImage` and `settingsLogoImage` hold separate choices:
empty for the wordmark, `builtin:omarchy-pixel` for a stepped accent glint, or a
validated local file URL. Missing values fall back to the legacy `logoImage`;
an explicit empty value resets only that slot. `hoverLogo` and `settingsLogo`
remain separate visibility switches. Independent `hoverLogoLoop` and
`settingsLogoLoop` default to true; their mini switches keep a constant label and
appear only for a GIF or the pixel preset. `hoverLogoLoopDelay` and
`settingsLogoLoopDelay` store seconds separately, defaulting to 4.2; normalize to
milliseconds in the range 0–86400 seconds. The input accepts decimal dots or commas
and commits on Enter or editingFinished. Pauses are canceled while hidden.
Independent `hoverLogoCooldown` and `settingsLogoCooldown` default to zero seconds;
the `...CooldownUnit` fields select seconds or minutes without changing duration.
Reset buttons restore 4.2 seconds for loop delay and zero for cooldown.
`Runtime.logoAnimationHistory` records each slot's source and last animated
appearance across monitors for this shell session. Hiding an animated logo starts
the cooldown; a blocked reopening stays static and does not extend it. Changing
the source permits immediate playback in independent mode. Optional shared mode
uses one cooldown and a source-independent history for both slots: any admitted
animation blocks the other slot too, including across monitors. An active shared
animation holds the cooldown until hidden; rejected openings never extend it.
Zero disables the delay. Individual values survive switching shared mode off.
The history is not persisted.
`LogoImage` uses an uncached, size-bounded
AnimatedImage for GIF and Image for static files. GIF and built-in playback stop
when the item or its window is hidden. Play once stops the pixel sweep and pauses
GIF on its final frame; showing it again restarts at frame zero if its cooldown permits. Loop mode
also repeats GIFs whose own metadata specifies a single playback.
`LogoPicker` is an item popup on the existing
layer surface, so a file chooser never competes with the panel for keyboard focus.
It resolves the overlay from the invoking control every time; attaching to its
own overlay can retain a destroyed window after the compact/expanded lifecycle.
It browses readable local images, previews before Apply, and leaves preferences
unchanged on Cancel/Esc. The path field accepts folders or full image paths,
including spaces and reserved URL characters; failed decoding disables Apply
and shows an error. Both settings and chooser name the supported formats.
Background instructions and logo help use separate
`PanelHint` instances. Logo, controls and background help share the enabled state
and automatic display budget; only the help toggle's explanation is exempt.

Opt-in `doubleClickExpand` pins compact geometry while keeping the regular open
lifecycle, keyboard access and outside-click dismissal. The bar uses Qt's double
click interval; only a later single click closes an already open panel. Default
single-click behavior and the keyboard opening shortcut remain unchanged.
Both bar double-click input paths share `toggleBarExpansion`, cancel the pending
single-click close and use the panel's existing expand/collapse transition.
The layer input region covers the panel, open popup and its own bar label; other
bar buttons and underlying applications remain reachable. While mapped, an
anchor-sized input area forwards single/double-clicks to the same widget handlers.
This preserves a double-click across mapping and the initial exclusive keyboard
prime. The bare bar keeps its own transparency gesture. After the mask commits,
hit testing is refreshed at unchanged cursor coordinates so a stationary cursor
cannot remain assigned to the old fullscreen input region.

`WindowPanel` uses `HoverFootprint` to temporarily keep
the pre-collapse input footprint. A passive pointer handler releases it when the
pointer reaches the new card or leaves the old area; there is no keyboard grab
or ongoing timer while the pointer remains stationary in the vacated area.

All private binding handles are checked with `tostring` before `set_enabled`.
Hyprland 0.56.2 exposes expired weak handles as `HL.Keybind(expired)`; toggling
one without this guard can dereference a null shared pointer. Installation
recreates only expired handles and reuses live ones, including partial expiry.

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
Expanded Search retains keyboard focus independently of pointer position, including
with an empty query. Ordinary compact browsing follows the user's mouse-focus policy:
without an opt-in protection mode, it does not lease click-to-focus. Under focus-follows-mouse,
leaving for another window releases the keyboard; hovering the panel again is enough
to resume typing. The compact view focuses the same text field, clipped until expansion;
its first text edit expands through the host widget and enables the Search hold.
Configured actions run before text input, and promotion preserves the first and
subsequent characters without reinjecting key events. The keyboard is returned on
close, not on releasing Ctrl. After priming, the layer uses OnDemand so outside
wheel events and bar clicks remain available. `SearchFocus` temporarily sets
Hyprland's runtime `input.follow_mouse` to 3 while acquiring keyboard focus and
while expanded Search actually owns the keyboard;
this prevents pointer movement from changing keyboard focus. Its compositor-side
750 ms lease restores the original value on a stopped shell. Closure or actual
keyboard loss releases it immediately, without waiting for lease expiry.
Otherwise an inactive panel would keep unrelated application windows in
click-to-focus mode: pointer-driven focus changes could wait until another X11
resize request forced a refocus. Clicking the panel primes a new acquisition and
lease in Search; returning by hover remains available under focus-follows-mouse.
Focus loss alone never reacquires it. The one-time pointer hit-test refresh after
priming also runs in compact mode, independently of the Search lease. Renewals
run every 250 ms, ownership prevents stale releases, explicit external changes
win, and a config reload becomes the new restore value. No config file, mouse
speed or acceleration is changed. Exclusive layers and focus grabs in Hyprland
0.56.2 capture pointer input as well, so they cannot provide this combination.
There is a confirmed [X11 resize exception](#x11-resize-requests-and-keyboard-focus)
to this focus retention. `FocusRecovery` provides two opt-in native-window modes:
a temporary grant for an attributed incident, and the default-off `keepSearchFocus`
preference under Controls → Troubleshooting. The manual mode blocks outside wheel
and touchpad scrolling instead of yielding. It requires no source identity and
holds only the eligible search view. `FocusInterruptions` separately counts three
settled losses in two minutes to suggest the setting without changing input or
preferences. See [FOCUS_RECOVERY.md](FOCUS_RECOVERY.md) for evidence, lifetimes and
limits. Both modes ship in the plugin and use runtime leases on its own window;
neither requires replacing the compositor or editing configuration files.
Settings and Move menus do not hold this lease. The list first primes keyboard
focus unless the pointer is already on the preview. The preview
forwards key events to the source list's locally focused control when its XDG
popup receives the keyboard. Local focus follows search and row navigation even
while the source window is inactive, including the compact search field.
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
It briefly primes keyboard focus, then uses on-demand focus; its input mask covers
only the menu card so outside scrolling reaches the application. The main panel
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

### X11 resize requests and keyboard focus

Verified with Hyprland 0.56.2, commit
`efb50993780079460b0cbed1363e2166a2de1d9f`.
In [`CWindow::onX11ConfigureRequest`](https://github.com/hyprwm/Hyprland/blob/efb50993780079460b0cbed1363e2166a2de1d9f/src/desktop/view/Window.cpp),
the branch rejecting a tiled window's configure request calls
`CInputManager::refocus()`. That forces a hit test and keyboard focus change,
bypassing the `follow_mouse=3` lease. RSI Launcher through Wine produces repeated
requests; a fictional X11 client calling `XResizeWindow` reproduces the same
loss without RSI or any other user application. An independent layer panel also
loses focus with WindowPeek and the Omarchy shell stopped.

Ordinary floating resize requests take a different branch without that forced
refocus. This explains the tiled/floating difference. It is not a guarantee for
every floating state: fullscreen, interactive dragging and suppressed configure
requests share the rejection branch. In particular, `suppress_event` with
`x11configurerequest` still enters that branch; it is not a fix.

The result depends on the pointer target: an application under it can take the
keyboard, including after search results shrink the panel. Empty desktop space
did not cause the same loss in the reproduced case. This is compositor focus
loss, not a QML field losing its local `focus` flag.

The available plugin-side alternatives have been checked in a private compositor:
exclusive layer focus survives the resize requests but captures outside wheel
input; `HyprlandFocusGrab` does not prevent the reproduced loss either.
Repeated exclusive acquisition produces a focus loop. None
meets the combined requirements of uninterrupted typing, outside scrolling and
normal dismissal, so none is enabled as a fallback. Do not silently float,
suspend or otherwise modify unrelated applications to protect WindowPeek.

Buffering and replaying the first outside wheel event can preserve its amount
in tested configurations, but is not an enabled fallback. The panel receives
an already scaled delta. Without a window scroll override, replay must undo the
replay device's effective factor. With an override, it must instead undo the
original device's factor and let the destination window apply its override.
Dividing by the global factor alone is incorrect when device factors differ.

This compositor's public queries do not provide all the required information:
device factors are reported to two decimal places, and a window's scroll value
does not distinguish an explicit override from an equal inherited default.
Device-filtered wheel bindings can identify the source of some events, but are
throttled by `binds.scroll_event_delay`. Integer wheel conversion adds another
rounding step. These limits must be handled before treating replay as a general
solution; changing the event source to avoid rounding changes client behavior.

Matching Qt's `angleDelta` is not sufficient evidence of equivalent scrolling.
With source factor 2 and replay factor 1, a full notch gives `value120=240` in
both paths, but the replay produces `axis=15, discrete=1` instead of the native
`axis=30, discrete=2`. A receiver using pointer version 7 therefore scrolls half
as far. Discrete-scroll emulation also shares an accumulator across devices:
capturing and replaying an event can advance it twice. Even with emulation off,
Qt's integer angle delta does not preserve the original continuous axis value.
Acceptance must compare the Wayland event fields and older pointer clients,
not only the amount seen by a modern Qt receiver.

A temporary `no_focus` window rule is not a suitable substitute for the focus
lease. This compositor also excludes those windows from pointer hit testing;
the private test still lost panel focus. A rule that prevents keyboard focus
cannot be assumed to preserve mouse delivery.

Upstream work offers a possible native alternative:
[Hyprland #15899](https://github.com/hyprwm/Hyprland/pull/15899), merged on
2026-08-21 after v0.56.2, removes the forced pointer routing to exclusive layers.
This should allow a card-sized input region with exclusive keyboard focus and
original outside pointer events. Native tests of unmodified upstream commit
`23118f9f7f24db7447069949c2df7fcd8ba380d0` confirm exact first-wheel delivery,
including pointer v7 at 200% UI scale. They also confirm that this is not a
complete focus fix: repeated X11 configure requests still steal the keyboard
when the pointer targets the application active before the panel opened.
Another application under the pointer is correctly rejected by the exclusive
guard in `rawWindowFocus`; the remembered active window can instead reach
`rawSurfaceFocus` directly. A control without the X11 sender retains focus.
The unchanged OnDemand panel also still fails with this upstream revision.

A separate diagnostic build of that revision removed only the forced
`refocus()` from the rejected X11 configure-request branch, retaining
`sendWindowSize(true)`. With the unchanged OnDemand panel, native tests then
passed typing outside the panel, original first/second wheel delivery and
outside-click dismissal at 100% and 200% UI scale, including a pointer-v7
receiver. The X11 sender continued requesting geometry and receiving synthetic
ConfigureNotify replies. The unmodified-build control still lost focus.
This supports repairing the compositor's geometry-request path; it is not a
shipped plugin workaround or evidence of complete compositor regression
coverage. No patched compositor or native addon is installed by WindowPeek.
Neither compositor replacement nor permanent Exclusive is therefore an enabled
WindowPeek fix. A passing test of only a different pointer target is insufficient.

A plugin-API-only prototype used a card-sized native toplevel and `stay_focused`,
releasing that property in a non-consuming Lua wheel callback before the original
axis event was dispatched. It passed isolated typing and first-wheel checks on
unmodified 0.56.2 at 100% and 200% (pointer v7). It failed FINGER scrolling and
rapid inside-to-outside scrolling with the default binding delay: named wheel
callbacks are source-limited and throttled. It is not a supported fallback.
Changing all users' wheel-binding delays would still not resolve FINGER input.
Controls without any X11 resize sender reproduced both scrolling failures;
they are side effects of the prototype even on otherwise unaffected desktops.
Ordinary wheel packets passed in that control, while keyboard focus remained
in search. Removing `stay_focused` does not itself guarantee keyboard handoff
under `follow_mouse=3`; the earlier X11 case also had a later forced refocus.
The workaround is never global by default. `FocusRecovery.qml` now connects
`FocusIncident.js`, a passive X11 geometry observer and a consent dialog to an
optional native-window backend. Permission follows only the exact source window
until it closes, manual stop or reload. Its input limitations are shown before
approval. See the [detection and recovery contract](FOCUS_RECOVERY.md).

A later plugin-side prototype opened and destroyed its own temporary toplevel
around Exclusive panel acquisition. On unmodified upstream `23118f9` it removed
the remembered-application bypass described above: outside typing, original
wheel delivery and dismissal passed at 100%, pointer v7 at 200%, and for a
synthetic FINGER axis. The same test without the temporary window lost focus.
On stable 0.56.2 the prototype still blocked scrolling, so it does not fix the
currently supported installation. It relies on upstream's newer pointer routing,
is not deployed, and has not validated keyboard opening, monitor transitions,
focus history or transient-window lifecycle and visibility.

Restoring focus only upon a key press was also tested on stable 0.56.2. The
original key reached the plugin's Wayland surface but did not enter the search
field after activation; the control without X11 resize requests passed. Qt
defers window activation to a Wayland sync, and keyboard leave also stops its
repeat timer. On-key refocusing is therefore not an enabled fallback either.

[Noctalia's grab rearming change](https://github.com/noctalia-dev/noctalia/commit/0565d25c1d3f13c7432fd64d32d08e27dbaff444)
addresses focus ordering when relaxing Exclusive to OnDemand. It does not
establish protection against repeated X11 configure requests: upstream forced
refocus can still clear a seat grab outside its accepted surfaces. Neither
upstream approach has been enabled here based only on source review.

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
settings scroll position, expanded category and entry focus. All logo controls
live in the Pictures and Gifs subview of Personalization. `LogoCooldownControl`
provides the same fractional seconds/minutes, validation and reset for shared and
individual durations. Returning with the pointer does not reveal the previously
focused control; only keyboard navigation requests automatic scrolling. `SettingsSection`
owns its collapsed state and a keyboard-accessible outlined header. Hidden contents
remain instantiated but cannot receive pointer or Tab input; collapsing closes
open pickers. Expansion settles the inner and outer layouts and only reveals the
header if needed; it never scrolls to fit the whole category. This UI state is not
written to preferences. Settings requests a fixed 640 logical pixels, capped by
the native surface's available monitor area, with a scrollable interior.
Switch tracks use the resolved accent directly, including theme-specific Colors
rules, while their knob position distinguishes the saved on/off state.
Compact rectangular switches highlight on hover or keyboard focus. The two
Loop animation switches also stay highlighted while checked.
`EditField` wraps the native text field in every editor, search and file picker.
A passive `PointHandler` above the current window's content ends editing on an
outside press, including non-focusable captions and switches. It respects clipped
and scaled bounds and leaves clicks, text-selection drags and wheel events alone.
Hiding or disabling a field also releases its focus. Existing editing-finished
handlers retain their save/draft behavior; losing window activation alone does
not clear local focus needed by preview key forwarding.
The main window search opts out of outside-press blur so background clicks leave
it ready to type. Shortcuts still run before text input, and Settings, dialogs
and explicit keyboard navigation can take focus normally.
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
receives keyboard input and creates no dismissal surfaces on other monitors.
The gap follows the adjoining card edge for every bar position and shares the
same native input mask. A stationary pointer there retains hover; clicks have
no action. The region stops at the bar edge, leaving bar buttons reachable. `Widget` applies
the configured opening delay (400 ms by default) only to a new hover session; returning to its label
retains an already open hover immediately, ahead of the 160 ms leave timer. Clicking the
bar expands its width from 420 (360 in compact density) to 500 over 200 ms,
revealing search, Move, Settings and footer controls. The card does not fade or
remap during that transition. Its opening origin is retained where screen bounds
allow, and rows keep their identity, order and scroll offset. Typing also expands
the card and filters results immediately. Search retains keyboard focus with the
pointer outside; Settings and transient menus use their usual focus lifecycle.
Direct opening starts expanded. Expanded and pinned compact modes own the bar
coordinator. A short fullscreen input region is retained during focus priming:
Hyprland rechecks pointer focus when Exclusive becomes OnDemand, so shrinking
first would send keyboard input back to the application. The region then shrinks
to the card and popup. No dismissal surfaces are created on other monitors. `OutsideClicks` observes left/right/middle presses through
non-consuming Hyprland bindings, closing only outside the card, open popup,
invoking bar label and preview. Each open session has a token and a 750 ms lease,
renewed every 250 ms; close, expiry and destruction disable only its own handles.
Expired handles are checked before every enable/disable and replaced on reinstall.
Wheel callbacks also refresh compositor hit-testing at the unchanged cursor
coordinates, then pass the original event. This covers scrolling without any
mouse movement after keyboard opening: Hyprland otherwise keeps the old pointer
target after the input region shrinks. No wheel events are synthesized and no
cursor coordinates, acceleration or system mouse settings are changed. Panel dimensions are clamped to the screen before
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

`WheelScroll` scales mouse-wheel travel using the saved `wheelScrollSpeed`
percentage (50–300%, default 102%). It uses each Flickable's native animation,
temporarily applies wheel deceleration and restores drag deceleration when the
wheel flick ends. Pixel-based gestures and clicks pass through. Window lists,
settings editors and dropdown lists share this behavior.

Row hover remains active during wheel scrolling, inertia and thumb dragging.
The window under the pointer keeps its accent frame and color transition.
Hints are passive surfaces in the same window, outside the list's clip. Unlike
Qt Quick popups, they do not intercept hover, wheel or clicks over nearby rows.
Control hints follow a passive cursor observer attached to their control, with a
scaled gap below the pointer and an above-pointer fallback near the bottom,
clamped within the window. Attaching the observer to the control preserves it
when Quickshell replaces the panel's backing window.
Background, row, footer control and both logo hints anchor to the whole panel's
bottom edge, independent of the pointer or logo position. They clamp near the
window bottom if there is insufficient space below. The placement anchor is
separate from the text's scale, which still follows its control. General instructions
are suppressed over rows (including their retained preview hover), scrollbar,
search, Settings, logo and footer controls, even if the underlying background
MouseArea also reports hover. Row hints are enabled in expanded, pinned compact
and passive hover modes. Only the displayed hint consumes the budget. Background
help names only the current expand/collapse action and correct single/double click;
it stays hidden when collapse is unavailable. Automatic status text combines the
remaining count with the location of the ? switch; manual hints have no footer. Settings
and Controls help separately explain pinning via the bar label.
The bar name has its own bottom-anchored hint inside the panel and excludes the
background hint. It follows pin state and the available bar action. Hint rendering
removes final full stops from each line, preserving punctuation within sentences.
The original saved key `pinByTitleClick` now controls all compact pinning; keep
that key so an already-disabled preference remains disabled. With it off,
`Panel.open(..., true)` opens passive hover, even when automatic hover opening is
disabled; collapse releases controller ownership while retaining the hover surface.
The pending bar double-click interval keeps the passive surface available for
the second click. Changing the setting off also releases an already pinned compact
panel. The inner title has no custom click handler.
Text inherits the anchor's scale. Hints close when leaving the control or dismissing
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
Automatic hints show the remaining displays after counting their current
appearance. Manually enabled hints have no status footer. Reset controls and shortcut
help use the same component; pointer movement within a hint's target does not
consume more displays.
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
Window information remains available after the hint budget expires; only the
help tooltips participate in the automatic display count.

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

The preview flips at screen edges and follows the row during scrolling. Its top
is clamped to the visible parent card's top. In the panel it shares the existing
render surface; standalone hosts retain the popup/layer fallback. It has no
separate keyboard grab, and its pointer region makes it clickable. Nonblocking
hover tracking retains it over the list or preview. Transparent side strips
cover the visible gap, including after horizontal flipping.
A stationary pointer there keeps both cards open without a timeout;
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
`PopupMotion` uses the presenting `QQuickWindow` for expansion timing. Its
GUI-thread `afterAnimating` signal evaluates OutCubic progress from a monotonic
`ElapsedTimer` before scene synchronization; `frameSwapped` requests another
frame only while motion is active. This avoids presenting an unchanged width
when the general animation timer and the window's frames drift out of phase.
The same path follows the card between ordinary and protected surfaces.
Opacity and hosts without a visible window retain a standalone NumberAnimation.
Reversal starts from the current value, surface transfer pauses it, and disabling
motion finishes synchronously. Hidden or detached windows use the fallback so
completion does not depend on receiving another presentation callback.
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

Right-click navigation resolves the innermost visible popup before its parent.
Settings sections retain opening order for one-level collapse outside a section;
editors cancel drafts before returning to that same Settings section. Background
hints additionally require the panel bounds' current HoverHandler state.


## Hover on offset monitors

Hyprland 0.56.2 can send a new focused layer an initial pointer-enter coordinate
with the monitor offset subtracted twice. On a second monitor at x=1920, the
private reproducer received x=-1853 instead of x=67. Qt consequently considered
the bar anchor unhovered and WindowPeek repeatedly dismissed/reopened its panel.
`BarAnchorHover.qml` confirms the label bounds using read-only, token-matched
cursor queries while the panel is mapped. Replies expire after 200 ms; closing
stops observation. It creates no input bindings or pointer motion. Dismissal is
rearmed only after a settled exit, so Esc cannot immediately reopen the hover.

### Readability

`ReadableText` and `ReadableButton` apply a native Qt raised text shadow without an
extra offscreen blur layer or a backing rectangle. Personalization saves
`textShadowMode` (`auto`, `on`, `off`). The automatic estimate compares each text
color and its alpha with sampled wallpaper colors, the panel tint, transparency
and nearest row backing. Solid panels stay unchanged in Auto. For glass, light
and dark backgrounds are checked conservatively without capturing other apps.
`TextShadowSampler` runs only for an open wallpaper panel in Auto. It debounces
geometry changes and caches 64 RGB samples from a small local crop; changing a
setting or theme re-evaluates contrast without processing the image again.
`TextReadabilityService` groups labels by original, theme and backing colors and
sends their contrast decisions to the existing `wallpaper_contrast.py` helper.
A bounded JSON-line worker handles repeated batches without launching a process
per color change; it exits after 15 seconds idle. Quickshell owns its lifetime.
This avoids the WorkerScript teardown crash reproduced with Qt 6.11.2 and
Quickshell 0.3.1. The Python policy is checked against the JS rendering policy.
The UI never scans wallpaper samples for each label. Requests are coalesced into
batches of at most 64 roles, with a bounded role cache; context generations reject
obsolete replies. Existing ink stays stable while new results arrive, and only
changed decisions invalidate label bindings. An inexpensive first-use fallback
keeps the panel ready before a result exists. When the wallpaper is pending or
has no matching sample yet, that fallback remains in use: missing samples are
not evaluated as a solid panel tint. A source change invalidates old sample
identity and settled decisions. This prevents an early guessed result from
dimming text between first paint and the real contrast result. Explicit Off restores native ink
immediately. The sampler retains up to eight crops so repeated expansion and
collapse reuse image analysis. These changes avoid synchronous contrast work
when a delayed sample arrives during another animation; they do not change
preview-window synchronization in Qt.
`ReadableText.textColor` retains the original role independently from rendered
`color`, avoiding contrast/color binding loops. With protection enabled, faint
letter cores become opaque; unreadable mid-tones use the theme text color. Native
button labels use the same policy while preserving their original color bindings.
Off restores original rendering. Count badges use body-small bold text, so a
one-pixel shadow cannot dominate tiny caption strokes. No saved color is changed.
Detached preview scenes, hint bubbles and popup content explicitly carry their
owner and backing color after reparenting. Preview labels reuse the panel contrast
samples; captured application pixels are unchanged. `EditField` corrects native
input ink while preserving selection, cursor and IME. Empty-field placeholders
use solid theme text with a glyph shadow when needed; the native placeholder is
then transparent, so the hint is never drawn twice. Off restores native colors.
This is a readability heuristic, not a guarantee for every pixel or custom theme.

`ReadableBarButton` decorates only the active vendored WidgetButton label. The idle
label always keeps its original color and has no added shadow. Contrast uses the bar background and adaptive foreground, independently
of panel style or wallpaper samples. Auto preserves legible accents on opaque
bars; transparent bars use a conservative estimate. On/Off apply here too.

Osaka Jade uses its bright yellow (`#E5C736`) as the active bar label contrast
fallback unless the user selected a custom accent. Idle text is unchanged.

The vendored WidgetButton exposes `animateTextColor`; WindowPeek disables it so
ink and glyph shadow change together on activation/deactivation. The shell
otherwise fades color over 160 ms while style changes immediately. Shadow color
is derived from final ink, never an intermediate animation color.


### UI work and preview placement

The settings tree stays prepared while hidden, but freezes its layout width.
Hidden labels do not submit readability work. `WindowState` always publishes
fresh raw snapshots/revisions for focus diagnostics; the normalized list changes
only when list data changes. Window geometry polling therefore does not rebuild
unchanged rows. Desktop-entry lookups are shared per class within each snapshot.

`WriteQueue` serializes asynchronous atomic `FileView` saves. Settings and incident
history publish only after `saved`, including editor completion, host updates and
ignore choices. Pending settings merge subsequent edits from either monitor;
hint reservations and wallpaper defaults use that pending state too. A failed
write rejects dependent queued writes, preserves committed UI state and reloads
the file cache before a retry. No `waitForJob` or blocking write remains on this
path. Opening the panel does not wait for a disk save.

`WindowThumbnail` uses the owning `WindowPanel.panelScene` when available.
Both normal and protected panels keep the card and live preview in the same render
surface. The protected native window has a stable monitor-sized transparent
viewport with a shaped input mask. Expansion changes item geometry, without a
native window resize/configure round trip per frame. The focus lease receives the
visible card bounds separately: transparent space still counts as outside for
wheel/button policy. Hyprland 0.56 first selects floating windows by their outer
rectangle, so a surface input mask alone is insufficient. While yielding, a
leased compositor timer excludes only WindowPeek's native window from focus
hit-testing outside its card, preview and dropdown. It updates the property only
on boundary crossings; an inside button restores routing synchronously. The
original outside wheel event passes through. The timer stops with the lease and
while Search actively holds focus. Its existing capture and owner survive expansion/collapse.
The blur region covers the rounded cards, excluding the transparent bridge.
Standalone hosts retain the previous popup/layer fallback. This changes neither
compositor rules nor application window geometry. See the measured comparison in
[Known Issues](KNOWN_ISSUES.md#choppy-resizing-with-a-visible-window-preview).
