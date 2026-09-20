# Tests

Run offline checks from the project directory:

```sh
python3 tools/check.py
```

Requires Node.js, Python 3, Quickshell, Qt Quick Test and the installed Omarchy
shell components. No dependencies are downloaded. These checks use temporary
profiles and fictional windows; they do not read the live window list or change
desktop settings.

After changing runtime code in a linked installation, run `omarchy restart shell`
before checking the installed widget. A plugin rescan can retain old QML
components as well as singletons. A passing test in a fresh process and
`ready: true` from the installed widget do not establish that both run the same code.

For Shift preview checks, `omarchy-shell sarr.windowpeek status` must include
`preview.supported: true` for every instance; `preview.enabled` reflects the
saved Window previews switch. While enabled and a row owns the preview,
`watching` and `shiftKnown` should be true. Holding Shift outside the preview
card should report `shiftDown: true` with `visible` and `mapped` false.
The status contains only preview-state flags, without window titles or key logs.

Native thumbnail checks use two disposable windows with fictional colored
content and an isolated settings profile:

```sh
python3 tools/test_capture.py
python3 tools/test_capture.py --scale 2
python3 tools/test_capture.py --hover-only --screen DP-3
python3 tools/test_capture.py --privacy-only --screen DP-3
python3 tools/test_capture.py --scale 2 --park-pointer --screen DP-3
python3 tools/test_capture.py --instant --scale 2 --park-pointer --screen DP-3
```

They use the production Panel/WindowPanel in both collapsed and expanded modes,
including the full-screen layer, its smaller visible card and content alias.
They compare captured pixels before and after a source repaint in both lists,
check the gap between the actual card and preview, pointer handoff, parent
retention, preview click/Ctrl+Shift+click, dwell delay, Qt wheel/click delivery, focus/workspace preservation,
ordinary and special hidden workspaces, the exact inactive group member, hint
limits and buffer release after hover or source closure. Group selection is
checked through `group.current`, not the client's `hidden` flag. Initial desktop
placement and focus are restored; existing window membership is checked.
Sources open on a temporary named workspace, so they cannot join the user's
active tab group. The helper waits for IPC readiness before creating them.
When two monitors are available, source windows use the other monitor to stay
visible during capture. All monitors' original workspaces and focus are restored.
The gap case holds the pointer still for 1.1 seconds, longer than both leave
delays combined, and requires both surfaces and the row highlight to remain.
It also checks that a gap click performs no window action, leaving releases the
capture, and the same behavior holds when the preview flips to the left.
`--image /tmp/windowpeek-thumbnail.png` saves only the fictional card.

The first phase sends Qt mouse events over three successive rows and back to
the first. It checks that each preview opens, the row retains its hover after
opening, and leaving closes it in both lists. It also checks a long title's two
rendered lines and truncation, row action hints with a preview open, and that
turning hints off keeps the preview available. `--hover-only` runs this regression
alone; `--screen` accepts an available monitor name, preferably one away from
the physical pointer. The later capture phase drives row request state directly;
pointer handoff and clicks still use Qt test events on native windows. These
checks do not simulate hardware input through the compositor. The optional
`--park-pointer` parks the compositor cursor outside the test surface and restores
it afterward, preventing native enter events from replacing QtTest hover when
a preview maps. It requires idle input. Keep it separate from `--pointer`, which
moves the compositor cursor along the tested path and also requires idle input.
A passed Qt-event test alone does not validate compositor pointer routing.
Existing scrolling tests exercise actual Qt hover delivery. Native tests require
the desktop renderer; offscreen tests cannot validate Wayland capture.
For a capture diagnostic, `--frames-only --park-pointer` checks ten alternating
source repaints, observes `frameSwapped`, and compares captured pixels after each
change. It uses the production capture component, without changing its behavior.

## Coverage

- Model cases: identity, hidden tabs, duplicate titles, literal Unicode search,
  special filtering, workspace order, incomplete metadata, stable selection data
  and session ordering across focus changes.
- Contract cases: complete snapshots, command quoting and destinations,
  preference revisions, all 30 catalogs, appearance/preset preservation and
  complete preview inventory, ordering and special-workspace filtering.
  Bring plans cover the invoking monitor, named destinations, missing monitors
  and windows, exclusion of special destinations and already-present tabs.
  Scratchpad moves cover a missing destination, existing metadata, rejection of
  arbitrary missing special workspaces and refusal to move a window into its source.
  Text-template cases cover bounds, allowed fields and variables, literal and
  nonrecursive substitution, translated fallbacks and all 30 catalogs.
  Delay normalization covers zero, bounds and malformed saved values.
  Instant-preview positioning covers both sides, scaling and offset monitors.
- 2 QML model cases run in Qt's JavaScript engine.
- Python installation and update cases cover copying, replacement, removal,
  development links, retained preferences and rejected update attempts. See
  the update test section below for the security and failure cases.
- Offscreen QML exercises search input, arrow/Enter/Shift+Enter navigation,
  removal of a selected window, explicit destinations, color editing,
  apply/cancel, shared settings, command serialization, completion checks and
  failure paths. Preference checks include a separate process restart, corrupt
  JSON and a directory that cannot be written. Hint checks observe actual hint
  displays across the automatic limit and manual overrides, including Escape,
  hover, wheel and clicks passing through a visible hint, plus scaled placement.
  Preview checks cover active-window priority,
  all windows/workspaces, hint independence and height bounds in 30 locales.
- Number shortcut tests cover Ctrl+1–9/0 at 100% and 200%, displayed window/tab
  ordering, filtering, named and special workspaces, numeric keypad input,
  missing positions, repeated keys and blocking in settings, menus and
  busy states. Both hover and search accept shortcuts, including Ctrl held before
  opening. Tests check Ctrl press/release hints, scrolling with a partly clipped
  first row, matching labels and activation, and exclusion of offscreen targets.
  Workspace headings do not count as positions. Right-aligned numbers are checked
  alongside Active in English and Arabic; the option persists across restarts.
- The scrolling regression case refreshes window titles every 35 ms during
  stationary hover and consecutive wheel events in both the preview and search
  panel. It checks persistent row controls, continuous highlighting and no
  backward scrolling at 100% and 200% scale. It verifies the row underneath the
  pointer remains highlighted during wheel motion. Keyboard focus stays in search.
  It also exercises edge overshoot, the return to rest, switching the spring
  effect off during rebound and enabling it again. Settings tests cover the
  toggle, synchronization across monitors and persistence through restart.
- The interaction regression changes all 40 fictional titles every 35 ms,
  alternating short and long text. It checks stationary and clipped-row hover,
  Move, scrollbar size at rest and during movement, steady thumb color,
  scrolling in both directions with active hover, and hint dismissal on panel closure.
  It runs at 100% and 200% scale with hints explicitly enabled.
- The border regression samples painted outline pixels as a Flickable moves.
  It checks intermediate fade frames, increasing/decreasing hover brightness
  and constant selection brightness at 100% and 200% scale.
- The activation case sends plain, Ctrl+click and Ctrl+Shift+click events to both production
  views, verifies the move chooser without dispatching a move, distinct actions and busy-state blocking, and displays the
  localized gesture hint at 100% and 200% scale.
- Delay controls cover keyboard entry, independent values, failed saves and
  cross-monitor synchronization. Preference failure/restart tests retain zero
  delay and disabled animations. `privacy` covers immediate thumbnail opening,
  changes to a pending delay, cancellation, unknown Shift state and Ctrl+Shift+click.

`python3 tools/test_ui.py timing-native --desktop` checks the production bar
button and panel with zero and positive delays, immediate expansion, interrupted
fades, unmap callbacks and rapid reopening. It also checks the unanimated preview
layer, placement at either edge, pointer handoff and Shift. Repeat with `--scale 2`. This moves
the desktop cursor and requires idle input; the runner restores its position.

Run a particular case with `python3 tools/test_ui.py panel`. The panel accepts
`--scale 2` and `--image /tmp/windowpeek.png` for a fictional-data capture.
Use `preview` for the bar preview. `--style compact` selects the denser layout in
`panel`, `preview` and `scrolling`. The panel case checks that live density changes
preserve row identity and selection, update the scroll extent and revert on Cancel.
It also checks numeric destination search with the workspace prefix. The preview
case checks header alignment and non-overlapping labels across all 30 languages.
It also checks that only hidden workspaces have status labels, including updates
when changing a workspace or opening a special workspace on another monitor.
Use `move` for the fitted move form, source label and scratchpad shortcut above the dropdown.
It checks the real Qt click, empty search results, busy and closed-window guards,
already-present windows, height changes and translated layouts at the selected scale.
Its action recipient is a fake host; it does not move desktop windows.
Use `list-height` to check complete bottom rows in both list densities and views,
screen limits, orphan headings, short and empty searches, and stable sizing while
scrolling or updating titles. It also accepts `--scale 1.25` and `--scale 2`.

Use `labels` for text editing, or `labels --scale 2` for the larger layout.
It checks real Qt typing and caret preservation, invalid variables, Apply,
Cancel, Back, Escape, dismissal, reset, failed writes and long action captions.
All five field groups are laid out in all 30 languages while retaining custom
text. The `widget` case checks shared previews and owner-specific cancellation;
`preferences` checks custom text after a process restart. These isolated cases
do not change the user's saved labels or send input to the desktop.
Use `review` at 100% or 200% for failed dropdown writes, cross-instance selection
updates, Back navigation, confirmation focus, Tab scrolling through Settings
and a 40-window list, and footer spacing in all 30 languages at a narrow width.
`--image /tmp/windowpeek-review` also saves fictional snapshots of the main views,
including each settings section. The review covers return focus and scroll;
`panel` checks immediate density changes, failed writes and cross-instance state.
`editor` verifies color Apply preserves density and scale changed during editing.
The `widget` case verifies appearance preview ownership without a monitor name,
cancellation by the owner only, and cleanup when its widget is destroyed.
Use `scrolling --surface panel` for the full panel's scroll regression.
Use `interaction` for the longer hover, hint and scrollbar regression.
Use `privacy` (also with `--scale 2`) for preview suppression in both views,
fresh dwell on release, the card-only exception, capture unloading, retained
Ctrl+Shift+click actions, Ctrl-only preview clicks that request the chooser, and late replies. It also checks the Window previews setting:
disabled hover, closing an open card, stopping capture and modifier observation,
reenabling with stationary hover or held Shift, and retaining row actions.
`panel` checks the Settings switch, `widget` checks monitor synchronization and
`preferences` checks disabled previews after a process restart.
This offscreen case supplies Shift-state
samples explicitly and sends real Qt pointer events. It does not establish
compositor keyboard-state observation.
`test_capture.py --privacy-only` checks that separately with disposable windows
and a test-only Wayland virtual keyboard: left/right Shift, stationary
press/release, real capture release,
card and row Ctrl+Shift+click, and leaving the card through the gap. Run it on an idle
desktop; it briefly takes keyboard focus and generates Shift and Ctrl key events.
It also checks that either Ctrl key alone leaves the preview visible.
Keyboard state is read through the compositor; pointer events come from QtTest.
Action assertions use FakeHost and do not move the user's windows.
The helper needs `cc`, `wayland-scanner`, `pkg-config`, `wayland-client` and
`xkbcommon`. It is compiled in the temporary profile and uses standard evdev
modifier codes, so Hyprland sees the same symbols in its binding keymap. The key is
released when the test closes stdin, on termination, or after a ten-second limit.
The protocol in `tests/protocols/virtual-keyboard-unstable-v1.xml` comes from
[wtype](https://github.com/atx/wtype/blob/master/protocol/virtual-keyboard-unstable-v1.xml)
and retains its MIT notice. These are test dependencies, not plugin requirements.
The example [preview image](hover-preview.png) contains only fictional windows.

## Native checks

These briefly take keyboard focus and require an active Wayland/Hyprland session.
Run them sequentially while the desktop is idle; do not edit a linked plugin or
restart the shell during a native test:

```sh
python3 tools/test_ui.py bar-return-native --desktop
python3 tools/test_ui.py bar-return-native --desktop --scale 2
python3 tools/test_ui.py bar-bridge-native --desktop
python3 tools/test_ui.py bar-bridge-native --desktop --scale 2
python3 tools/test_ui.py transition-native --desktop
python3 tools/test_ui.py transition-native --desktop --scale 2
python3 tools/test_ui.py native
python3 tools/test_ui.py native --scale 2
python3 tools/test_ui.py interaction-native
python3 tools/test_ui.py interaction-native --scale 2
python3 tools/test_ui.py hints-native --scale 2
python3 tools/test_ui.py borders-native --desktop
python3 tools/test_ui.py borders-native --desktop --scale 2
python3 tools/test_ui.py hover
python3 tools/test_ui.py hover --scale 2
python3 tools/test_live.py
python3 tools/test_live.py --window-shortcuts
python3 tools/test_live.py --held-shortcuts
```

The shortcut-only native run sends Ctrl+digit Qt key events through the
production panel at 100% and 200%. It verifies exact window and group-tab focus,
including named workspaces, scratchpad, repeated selection and another monitor.
It uses disposable windows, checks that existing windows and groups were not
changed, and restores monitor workspaces, focus and cursor. It requires idle input.

`--held-shortcuts` uses a native virtual keyboard for both Ctrl keys and digits.
It holds Ctrl before opening hover or search, matches the visible number to the
activated window or group tab, and checks both scales. It also presses Ctrl after
hover opens and verifies that releasing it returns keyboard focus without
expanding or closing the list. With a real pointer over a row, it checks digits
with Ctrl pressed before and after the content preview opens. Key delivery waits
for native window activation, not just the QML focus item. It uses the same
disposable windows and cleanup.

The bar-return fixture uses the production Widget and bar button with a fictional
inventory. It moves the compositor cursor and delivers matching Qt mouse events through
the label, gap and card three times, checking that opacity never falls, the native surface never remaps, and
scroll, row identity and hint count remain unchanged. The first opening still
waits for dwell, and clicking the label expands the same surface. It restores
the cursor afterward and requires idle input. A native virtual keyboard holds
Ctrl with the pointer stationary on the bar, both before and after hover opens;
the fixture checks for repeated mapping, fading, hint consumption and scroll resets.
Releasing Ctrl and leaving the bar must close hover normally. Cursor warps alone can leave
Qt hover coordinates stale within one native surface; this test is not a
hardware mouse-event simulation.

The bar-bridge fixture checks all four bar positions, native input bounds that
include the gap but exclude the bar, a stationary pointer beyond the leave/fade
delay, passage in both directions, inert Ctrl+clicks and closure after leaving.
It sends Qt mouse events and needs idle input, like the other native fixtures.

The transition fixture observes rendered frames through the card's native
QQuickWindow. At 100% and 200% it checks one mapping, continuous card opacity,
rounded corners, row identity, scroll offset and a stable origin throughout
expansion. It also checks passive hover input bounds, keyboard pass-through,
immediate search typing, outside-click bounds, Escape and rapid reopening.

The native UI fixture uses the production panel with fictional data. It checks
search focus, Enter, distinct row/Move clicks, Escape and eight rapid reopen
cycles with hover, scrolling and live title updates. It also covers a scaled
language picker, screen bounds and footer placement for all 30 locales.
The cursor moves through Hyprland and returns to its original position when
the test exits; leave the mouse idle during the test. It does not act on real windows.

The native interaction fixture holds the pointer over a row and a clipped row,
then scrolls across several workspaces while changing 40 fictional titles every
35 ms. Hints are explicitly on; `--hints off` provides a diagnostic comparison.
The native hint case checks input through the visible hint in a Wayland window
without moving the physical cursor.
The native border case renders production row surfaces in a separate Wayland
window, without moving the physical cursor. It samples pixels with QtTest's
`grabImage()` while moving content and changing hover state. This verifies the
opacity fade's painted output, but does not reproduce wheel input or capture
every frame presented by the compositor; manual comparison remains necessary.

The hover fixture checks the production popup at native scale: focus retention,
keyboard pass-through, pointer entry and leave, the last automatic hint,
manual hint settings, live special-workspace filtering and dismissal when
another panel opens. A 35-window scenario covers mouse-wheel scrolling,
scrollbar dragging outside the panel, preserved scroll position after refresh
and clicking the last row. Its data and focus-probe window are fictional.

The compositor test creates four short-lived Foot windows on temporary named
and special workspaces. It exercises inactive workspaces, hidden group members,
locked-group refusal, single-member movement, special workspaces and a second
monitor when one exists. The production widget's hover is clicked to activate
a hidden group member and a window on another monitor, including native unmap
before focus dispatch. Hidden and visible special workspaces must keep their
monitor when focused. Ctrl+Shift+click in the hover brings a single scratchpad tab;
the full panel brings an ordinary window onto its own monitor. Further cases
cover locked groups, a workspace change between planning and dispatch, and
group preservation when the tab already occupies the destination.
Cleanup closes only test windows and restores each
monitor's prior workspace, special workspace and focused window. Original
window/workspace, monitor and group membership are checked in memory; titles are not
written to test artifacts.

With WindowPeek installed, include bar integration:

```sh
python3 tools/test_live.py --installed
```

This also checks opening on each monitor, the shortcut's IPC command, focus
restoration on close and focusing a test window through the installed widget.
It does not synthesize the physical Super+Alt+P keypress.

## Packaging

Refresh documentation images from the current controls and fictional data
using the [preview generation steps](PREVIEW.md). The root promotional image
combines that panel capture with a vector layout. Inspect the final PNG before
publishing it to README or the marketplace. No real windows are captured.

```sh
python3 tools/package.py
```

The reproducible ZIP includes the source, docs, licenses and tests. Private
handoff files, the pinned reference export, Git state and build caches are
excluded. Packaging neither creates a commit nor contacts a remote service.

## Validation limits

The reference desktop is Omarchy 4.0.4, Hyprland 0.56.2, Quickshell 0.3.1 and
Qt 6.11.2 with two monitors. Native layout was inspected at 100% and 200%.
Language checks cover keys, placeholders, runtime switching and footer bounds;
they are not a native-speaker review of every translation.

The updater's service responses are simulated in local tests. A real public
automatic update is reserved for an isolated profile after publication, as
described in [Publishing](PUBLISHING.md). Unplugging a physical monitor
mid-action and other compositor versions have not been tested.

## Update and preference tests

`python3 -B tests/test_updates.py` uses disposable Git repositories and the real
directory exchange, without network or desktop access. It covers:

- Successful replacement, full-project upgrade and unchanged preferences.
- Daily deadlines, new workers, parallel processes and malformed schedule data.
- Missing or revoked catalog approval, unknown schemas, mutable releases,
  wrong SHAs, changed tags and unavailable services, including the final check.
- Dirty files, hidden index flags, symlinks, submodules, executable mode changes,
  checkout conversions, filters, hooks and injected Git environment variables.
- Opt-out or local edits during download, validation/exchange/reload failures,
  unwritable state and unavailable preferences, metadata limits and child cleanup.

`python3 -B tools/test_preferences.py` runs 27 offscreen scenarios with real
atomic file IO, separate-process restarts and two widget instances. It covers
panel and Omarchy settings changes, stale monitor copies, host mirror failure,
corrupt/unreadable files, first-save failure and successful retries. These cases
and `python3 tools/test_ui.py updates` are included in `tools/check.py`. The
update UI test checks deferral, the shared launch throttle, saved opt-in and
Cancel/Escape/default Enter. No native keyboard or pointer events are sent.

Run `python3 -B tools/test_lifecycle.py` separately on Omarchy with Bubblewrap.
It uses the real plugin CLI and registry inside a private home/config/state
namespace, with no network or desktop sockets. It installs, enables, changes
host settings, restarts, updates, removes and reinstalls the fixture while
checking saved preferences and unchanged live configuration. A system sandbox
may require permission to create this nested namespace. Git commits made by
these tests exist only in disposable fixture repositories.

GitHub Actions pins external actions to full SHAs. It runs the Node/Python
checks and package validation. Its Ubuntu runner does not provide Quickshell,
Hyprland or Omarchy; native QML, the actual Omarchy validator and isolated
lifecycle checks run locally. Neither CI nor these tests establish catalog
approval or verify a future public release.

## Scroll rendering diagnostics

Native fixtures normally use the software renderer and Basic style for repeatability.
Use `--desktop` to retain the desktop's Qt style and renderer; `--software`
overrides only the renderer for an otherwise identical comparison. `--log` saves
the complete fictional-data trace, including the graphics backend.

```sh
python3 tools/test_ui.py interaction-native --desktop --log /tmp/windowpeek-hover.log
python3 tools/test_ui.py interaction-native --desktop --software --manual --log /tmp/windowpeek-hover-software.log
```

`--manual` leaves the fictional panel open for 75 seconds without moving the
cursor or changing titles. Hover events include row geometry and timestamps,
and the scrollbar trace records hover, press, size and color changes. In manual
traces the cached cursor position can lag a real mouse move; an `inside` exit
alone is not proof of incorrect input delivery.

Automated interaction checks sample hover after `frameSwapped`, because Qt
updates hover before rendering, after a timer can observe a new scroll position.
They also check that scrolling does not change the thumb size and that rendered
content offsets are pixel-aligned at 100% and 200% scale.

Relevant Qt documentation:
- [Variable delegate heights and scrollbar estimates](https://doc.qt.io/qt-6/qml-qtquick-listview.html#variable-delegate-size-and-section-labels)
- [Pixel alignment for thin lines in scrolling content](https://doc.qt.io/qt-6/qml-qtquick-flickable.html#pixelAligned-prop)
- [Item opacity](https://doc.qt.io/qt-6/qml-qtquick-item.html#opacity-prop)
- [Sampling rendered items in QtTest](https://doc.qt.io/qt-6/qml-qttest-testcase.html#grabImage-method)

## Popup motion

The offscreen `motion` fixture checks intermediate values, disabling an active
fade, instant open/close, reenabling motion and reversing an unfinished transition.
It exercises the same `PopupMotion` component used by the native panel.
[Qt animation control](https://doc.qt.io/qt-6/qtquick-statesanimations-animations.html)
describes standalone animations and their lifecycle.

## Background clicks and click-only mode

`background` tests route real Qt clicks through workspace headings, window rows,
Ctrl+Shift+click, search, Move and Settings, plus wheel scrolling and dragging from a
heading. It runs offscreen at 100% and 200% in `tools/check.py`.

The coordinated `timing-native --desktop` fixture also exercises repeated
background expansion/collapse at both scales. It samples rendered frames for
native surface continuity, opacity, corner radius, row identity and scroll,
checks keyboard and bar ownership, clears hidden search filters, and verifies
that click-only mode suppresses hover opening and collapse. Settings and move
backgrounds remain neutral. Preview placement is checked against Hyprland's
reported layer geometry; Qt's global mapping does not include the small layer's
screen margins. The fixture restores the cursor; do not run it while
the desktop is being used.

`bar-dismiss` exercises suppression, motion within the label, delay changes and
exit/reentry offscreen. `timing-native` also clicks the real full-panel input region
to forward a bar click, waits beyond the hover delay after closing, reopens by an
explicit click, and leaves/reenters with both normal and zero-delay/no-animation
settings. Run it at both scales when changing the bar-close lifecycle.

`python3 tools/test_ui.py gestures-native --desktop` checks the small destination
menu in hover, expanded and preview-card views. A test-only virtual keyboard holds
left/right Ctrl and Ctrl+Shift. Focused lists receive matching Qt click modifiers;
passive preview surfaces receive none, exercising the Hyprland sampling fallback.
Checks include unchanged list mode, search focus, selection, Escape, released
keys, Ctrl preview interactions and waiting for both surfaces before a bring action.
It also retains the originating preview in both list modes, with animations on
and off. A real cursor move verifies that the menu receives hover above the native
preview; right-click cancels the menu and releases retention.
Actions are recorded against fictional windows, not sent to real windows. Run at
100% and 200% with an idle desktop. `--compile-only` loads the fixture without
mapping a surface or sending input.

`click-modifiers` tests late/malformed replies, cancellation, target replacement,
timeout and stale Qt modifier state. `move-menu` checks placement and screen edges,
search, Escape, busy/error handling and the preserved list mode offscreen; repeat
with `--scale 2`. It also sends wheel events over overlapping scrollable lists
in both panel modes: normal menu scrolling, both edges, filtered results, heading,
search, padding and backdrop must leave the window list still. Closing the menu
restores scrolling beneath it. Neither offscreen case validates compositor key delivery.
The Scratchpad footer remains full width and fixed during scrolling/filtering,
is absent from list rows, and is disabled for windows already in Scratchpad.

`python3 tools/test_ui.py navigation` checks right-click Back on settings controls,
text fields, both dropdown types, editor drafts, the move form and update-disable
confirmation. It checks that right-click does not activate the underlying action,
and that primary clicks and hover still work. `background` checks main-list
right-click dismissal routing in both modes; `gestures-native` also checks that
the list and preview unmap after it. Repeat with `--scale 2`.
`privacy` also checks retained previews after leaving the card, blocked retargeting,
Shift privacy after closing the menu, and disabling previews while a menu owns one.

`dropdowns` reproduces trigger-click dismissal for both dropdown types, including
rapid clicks, outside clicks and Escape, without changing the selected value.
It also checks that the language list begins below its search field; use `--image`
to capture the open menu. Broken Column positioning fails the fixture runner.
`settings-sections` checks collapsed entry, mouse and keyboard expansion, closing
pickers on collapse, Tab skipping hidden controls, stable header position and panel
height during expansion, accent-colored switches, Back
from an editor and RTL navigation. It verifies scrolling through Controls to its
last instruction and wrapping in all 30 languages. Both run offscreen; repeat with `--scale 2`.
Use `--image /tmp/windowpeek-settings` with `settings-sections` for category views
in English, Polish and Arabic. `review` also covers delay layouts in all 30 languages.

`defaults` checks per-value resets by mouse and keyboard, failed writes and retry,
disabled dependencies, editor Apply/Back, and preservation of other settings,
theme rules and presets. It also checks translated default/reset layouts at a
narrow width in all 30 languages. Run with `--scale 2` as well.

`row-navigation` checks Left/Right between a window and Move, Up/Down in either
column across workspace headings, scrolling into view, RTL, query cursor movement,
text selection, busy actions and removal of the focused window. Repeat with `--scale 2`.
`preview-keys` activates the preview popup and checks that Ctrl+digits, search
input, Right and Enter reach the source list's current control. It catches keys
sent to a stale search field after focus has moved to a row's Move button.
`hints` checks that display 200 remains readable, 201 stays hidden, and the help
button enables unlimited hints until turned off. `widget` checks the shared
budget across monitors; `preferences` checks manual on/off across process restarts.
`scrolling` samples hover after rendered frames, alongside pixel alignment, rather
than immediately inside wheel delivery while geometry and hover may be updating.
It requires multiple sampled frames and exercises springy and firm boundaries.

### Pointer frame delivery

The native gesture fixture checks the real compositor cursor over the move
menu. After a Hyprland cursor warp, a small virtual-pointer helper sends a
motion/frame pair. This completes the Wayland input sequence; a warp that
emits motion alone can leave Qt waiting for `wl_pointer.frame`. The helper does
not move the pointer further or click. Its protocol license is included in
`tests/protocols/`. Build dependencies are `cc`, `pkg-config`, `wayland-scanner`
and Wayland client headers; the keyboard helper also uses xkbcommon.

The native gesture test also checks visual stacking in the compositor output.
A 4 × 4 pixel crop must show a marker on the move menu where it overlaps the
fictional preview. This needs `grim` and does not save a desktop screenshot.
`gestures-native --overlay-menu --desktop` forces the former layer-only menu
for diagnosis; its pixel assertion is expected to fail. Normal runs cover
hover and expanded lists with animations on and off, at each requested scale.
