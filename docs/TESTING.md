# Tests

Run offline checks from the project directory:

```sh
python3 tools/check.py
```

Requires Node.js, Python 3, Lua, bubblewrap, Hyprland, Quickshell, Qt Quick Test and the installed Omarchy
shell components. ImageMagick (`magick`) exercises the real wallpaper sampling;
that Python case is skipped when the binary is absent. No dependencies are downloaded. These checks use temporary
profiles and fictional windows; they do not read the live window list or change
desktop settings.

The final step builds the source ZIP and validates an extracted copy, so ignored
local diagnostics cannot contaminate release validation. To repeat only that check:

```sh
python3 tools/package.py
python3 tools/check_package.py --validate
```

CI runs every pure JavaScript suite, the Python unit tests and the same archive
checks without `--validate` (Omarchy is not installed in the CI image). Archive
checks cover module components, runtime workers, docs, matching versions and
exclusion of private notes and diagnostic modules.

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
hover opens and verifies that releasing it keeps typing focus without
expanding or closing the list. Closing returns focus. With a real pointer over a row, it checks digits
with Ctrl pressed before and after the content preview opens. Key delivery waits
for native window activation, not just the QML focus item. It uses the same
disposable windows and cleanup.

`--keypad-shortcuts` sends actual keypad keycodes through a separate virtual
keyboard, with Num Lock on and off. It verifies the selected row in hover and
search at both scales, including a grouped tab and a window on another workspace.
The lock state belongs to the test keyboard and is cleared before it is destroyed.
Offscreen shortcut tests cover all ten digits, scrolled rows, unchanged search
text, preview forwarding and dedicated navigation keys.

`--fast-keypad` opens each list before pressing Ctrl, then sends Ctrl and the
keypad digit in one Wayland flush without waiting for Ctrl hints or keyboard focus.
It repeats at both scales, selecting an exact hidden group tab. A disposable
terminal counts input bytes to detect leakage without recording their contents.
After closing, the same probe must receive input again. Terminating the fixture
also verifies the compositor's shortcut lease expires within two seconds.
The Lua lease lifecycle has an offline test in `shortcut-bindings.test.cjs`;
it requires the `lua` interpreter and checks owner isolation, expiry and handle reuse.

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
expansion. It also checks hover input bounds, keyboard focus retention,
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
typing readiness, Escape dismissal, pointer entry and leave, the last automatic hint,
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
handoff files, the pinned reference export, Git state, local Python helpers and
build caches are excluded. CI checks that the archive has no separate installer.
Packaging neither creates a commit nor contacts a remote service.

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
- Six-hour deadlines, new-day startup checks, same-day restarts, migration from
  daily deadlines, parallel processes and malformed schedule data.
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
checking saved preferences and unchanged live configuration. The saved values
include distinct per-theme Wallpaper levels, surface colors and presets,
custom shortcuts, preview choices, labels and scaling. A fresh install checks
Wallpaper with grain, no blur, a pending per-theme contrast assessment and the
full automatic hint budget starting at zero displays. A system sandbox
may require permission to create this nested namespace. Git commits made by
these tests exist only in disposable fixture repositories.

`python3 tools/test_ui.py glass` checks painted row contrast, opaque foreground
content, theme changes, the translated background picker, independent slider
values, reset, effects and failed saves.
Run it with `--scale 2` as well. Preference and widget tests cover restoring the
choice after restarting and sharing it between monitors.

`python3 tools/test_ui.py wallpaper-source` uses temporary images and a symlink
to check loading, cache invalidation after link changes and in-place edits,
missing files and the lifecycle of multiple panel consumers. It uses no desktop
input and does not alter the current wallpaper.

`WINDOWPEEK_TEST_BACKGROUND=/path/to/wallpaper.jpg python3 tools/test_ui.py wallpaper-opening --desktop`
delays the initial wallpaper lookup and checks every opening frame for premature
visibility. It also checks that fade-in remains animated, refreshing does not
hide the card, missing files fall back to solid, and early close leaves no mapped
panel. Run at both scales after arranging an idle desktop; `--compile-only` does
not show panels. The source test also covers reopening during a pending lookup.

`python3 tools/test_ui.py glass-native --desktop --image /tmp/windowpeek-glass`
briefly covers one monitor with a fictional backdrop. Set
`WINDOWPEEK_TEST_BACKGROUND=/path/to/wallpaper.jpg` for the wallpaper cases.
It checks all three modes, rounded blur regions, light themes, both preview
surfaces, wallpaper loading, missing-file fallback and stopping observation.
It saves compositor captures for visual comparison without moving the cursor
or sending input. Arrange an idle desktop first; run at both scales. Compare
`reference`, `aligned-raw` and `popup-raw` pixels in clear areas of each card to
verify wallpaper alignment. The striped backdrop must never appear in Wallpaper
mode. `effects` captures blur and grain; `fallback` checks an unavailable image.
Use `--compile-only` to check loading without displaying anything. Blur itself
must be checked in the compositor captures, not inferred from QML properties.

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
left/right Ctrl and Ctrl+Shift. Both focused lists and passive previews receive
clicks without Qt modifiers, exercising the Hyprland sampling fallback.
Checks include unchanged list mode, search focus, selection, Escape, released
keys, Ctrl preview interactions and waiting for both surfaces before a bring action.
It also retains the originating preview in both list modes, with animations on
and off. A real cursor move verifies that the menu receives hover above the native
preview; right-click cancels the menu and releases retention.
`--row-move-menu` opens the chooser from the list row while its preview is visible.
Both variants assert that opening and using the menu never unmaps the preview or
recreates its capture, in hover and expanded views with animations on and off.
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
confirmation. It checks section collapse before leaving Settings and closing a
picker by clicking elsewhere without collapsing its section. Right-click must not
activate the underlying action,
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
`settings-input` compares actual mouse-wheel travel with native Qt at 50%, 100%,
102% and 200%; verifies slider saving, reset and failed writes; and checks that
mouse returns hide the focus ring while keyboard returns retain it. Run at both
100% and 200% scale. After coordinating a desktop slot, repeat with
`python tools/test_ui.py settings-input-native --desktop` and `--scale 2`.
The native fixture targets only its own window. `scrolling` covers live refresh
and springy/firm boundaries.
`input-focus` checks outside-click blur and caret removal across text and numeric
editors, searches and the image chooser at 100% and 200%. It covers saved values,
non-focusable switches, selection drags, hidden/disabled fields and Tab traversal.
The main window search is the exception: background clicks preserve typing focus,
shortcuts do not insert text, and opening Settings releases search focus.
`logo-picker-native` repeats blur-and-save through both logo switches on the
production layer surface, including delivery of the same click to each switch.
`settings-panel-native --desktop` repeats the return paths for all four editors
and the speed slider in the production panel anchored to a fictional bar, at
both scales. Coordinate this desktop test separately; an ordinary test window
does not cover layer-shell focus or panel geometry.
`hints` checks that display 100 remains readable, 101 stays hidden, and the help
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


`surfaces` checks color roles, independent theme scopes, preset Apply/Cancel,
single-element and full-scope resets, and rejected writes. The preferences
fixture checks cold restoration of surface rules and full color presets.
`background` checks middle-button input alongside left/right clicks and scrolling.
The `surfaces` case also clicks the live appearance sample: panel, window fields,
active accents, menu and wallpaper. Repeat with `--scale 2`. It covers all three
background modes, RTL, unchanged drafts and saved values, and verifies that no
window action fires. `list-height` additionally checks that the editor opens at
the top preview, Apply is reachable on small screens, and preview clicks preserve
scroll and screen position after adding or removing role-specific controls.
`dropdowns` repeats open/close and keyboard checks for both picker types in Solid,
Wallpaper and Transparency, including a light theme. It checks their background
coverage and can save comparisons with `--image`; repeat at `--scale 2`.
Wallpaper checks include the popup's screen origin and unscaled background canvas.
`dropdowns-native --desktop` renders the same synthetic wallpaper through the
desktop renderer. Run it only during an agreed desktop test; its temporary
window can be constrained by the compositor at 200%.
It also checks wheel input on fitting, long, screen-constrained and filtered lists:
short lists stay still, long lists scroll, and boundaries do not scroll the editor
underneath. Repeat at a fractional scale such as `--scale 1.25`.

`quick-selection` checks bare digits on both keyboard sections, Num Lock-off
keysyms, visible-row numbering after paging, the actual five-second timeout,
ordinary search typing, row-action focus and cancellation on close/settings.
Repeat at `--scale 2`. `tools/test_live.py --quick-selection` uses disposable
windows and native unmodified digit events at both scales, verifies the exact
focused window/group tab, the timeout, unchanged groups and monitor placement,
then restores the desktop. Coordinate its timing with the user first.
`tests/shortcut-bindings.test.cjs` checks default-chord conflicts, handle reuse,
ownership, cleanup and expiry without editing real keybindings.

The native `glass-native --desktop` comparison covers custom fills, wallpaper
brightness, grain colorization, both editor preview modes, and middle-click
promotion/demotion at 100% and 200%. Captures use a fictional backdrop and list.


`tools/test_capture.py --geometry-only --park-pointer --scale 1` checks portrait,
landscape and live source resizing in hover and search, including dark-backing
and fixed-frame opt-outs. Repeat at scale2 and with `--instant` for both native
surface paths. It resizes only disposable fixture windows, compares captured and
displayed aspect ratios after reopening, verifies the open frame stays fixed
during a source resize, checks screen bounds and restores the desktop.

`--motion-only` measures source and preview frame presentation over five seconds
using a continuously animated fictional marker. It reports FPS and 95th-percentile
and maximum frame intervals; it avoids conflating discrete geometry-test steps
with live content playback. The cursor and desktop are restored by the fixture.

`--startup-only --startup-source wayland --park-pointer` records the first preview
frames for visible and inactive grouped windows. Repeat with `--startup-source xcb`
to cover XWayland. This diagnostic needs `qml6` and starts its animated source in a
separate process, so rendering the preview cannot drive the source's own animation
loop. It reports popup/content timestamps and source/preview frame intervals from
the start of each trial. A long source gap before popup visibility includes the
intentional hidden wait; it is not a measured delay after opening. Frame swaps
alone do not prove that every captured image contains newly rendered pixels.

## Wallpaper readability

`python tools/test_ui.py wallpaper-contrast` checks first-use sampling, theme
isolation, per-theme reset, manual priority, stale results, missing images and
failed saves without desktop access. It also delays applying a light theme's
palette after its name changes, checks that no old-color result is saved, and
exercises the actual Personalization slider's per-theme persistence.
`tests/test_wallpaper_contrast.py` checks palette matching as well as
the conservative trigger and local crop sampling using generated images.
After coordinating desktop timing, `wallpaper-contrast-native --desktop` checks
that first visible frames already use the adapted level, while acceptable
backgrounds remain unchanged. Repeat with `--scale 2`; `--image <prefix>` saves
the fictional panels. `--compile-only` maps no windows or input surfaces.

## Shortcut editor

`python tools/test_ui.py shortcuts-editor` checks draft isolation, Apply/Cancel,
reset, save failure, conflicts, custom navigation and digit selection (including
Num Lock off), standard Enter and RTL. Repeat with `--scale 2`.
`tests/shortcut-bindings.test.cjs` checks custom modifier leases and canonical
validation, alongside the default opener/number leases.

After coordinating desktop timing, `python tools/test_ui.py shortcuts-native
--desktop --scale 1` (then scale 2) uses fictional windows and a temporary
Ctrl+F24 handler to verify protected recording and release. It also tests custom
Alt+numpad in both views and Ctrl+click with deliberately stale Qt modifiers
while the hover already owns focus. The destination and shortcut menus must
use Wallpaper surfaces. The temporary handler is removed using its own handle;
a timer also releases it if the fixture exits early. No real window actions
are dispatched. `--compile-only` maps no windows and sends no input.


### Hover navigation and collapse

`hover-navigation` checks paging, selection, activation, remapping, keyboard
promotion and dismissal without a desktop, plus equal logo/expanded heights,
logo disabling and constrained height. Run it at 100% and 200%.
`hover-navigation-native --desktop` uses the production Panel anchored to a test
bar, a fictional background receiver and bounded virtual input. It checks that
typing expands and searches without leaking characters, search keeps focus with
the pointer outside, pinned compact also expands on typing, keys return on close,
remapped navigation and Ctrl+numpad work, and a stationary pointer survives
collapse with the logo on/animations on and logo off/animations off. Entering the
new card releases the old footprint; leaving then dismisses normally. The runner
restores the cursor. This fixture and `settings-panel-native` support
`--compile-only`, which maps nothing and sends no input. Coordinate desktop tests.

`hover-footprint` exercises the production retention component offscreen: resize
under a stationary pointer, re-entry, leaving and clicks in the vacated area.
`settings-panel-native` also checks Follow bar style, the unchanged Wallpaper
selection and returning to manual mode. `widget` covers the real PluginBarApi
binding and durable preference; bar state itself is never saved by the plugin.

`branding` checks independent logo switches, local-image persistence and fallback,
separate logo/background tooltips, exclusion over rows, the 100-display automatic
budget, and manual hints after that budget. Run it at 100% and 200%.
`hints` verifies cursor-relative placement and movement at both scales, screen-edge
clamping, automatic countdown and where to disable hints, no manual status footer, the last automatic
display, shared reset-control
help and input pass-through. Logo help consumes the same budget and hides when
hints are off or exhausted. `panel-hints-native` uses the installed host bar,
production Widget and layer panel with fictional window data. At 100% and 200%
it checks background and both logo hints against the actual panel bottom,
including screen-edge clamping, passive hover, compact and expanded views, and
a stationary hint while the pointer moves. At 200% on a 1080px output, Settings
content completely covers its logo; the test checks that its hint stays hidden.
It also checks footer hints after backing-window replacement, contextual row help
in passive hover and pinned compact views, remapped mouse modifiers,
row help with a visible native preview, and exclusive row/Move/footer/background
hints even when the underlying panel still reports hover. The automatic count
must increase once per actual hint, never for a suppressed background hint.
Run it in an isolated compositor; `--image` saves compositor screenshots.
`branding` also checks independent image/preset and loop choices, GIF frame
progression, stopping both animations while hidden, holding a GIF's final frame,
restarting single playback on reopening, and looping a GIF without a loop extension.
`widget` checks legacy shared-image fallback, individual reset and image/playback
synchronization across monitors.
`logo-playback` measures fractional delays between GIF and pixel animation loops,
zero-delay playback, stopping a pending repeat when hidden, and switching a
running animation to single playback.
`settings-panel-native` additionally browses a fictional local image, previews it,
applies it, and verifies that a real Escape closes only the chooser.
`logo-picker-native --desktop` uses the full host Bar and production layer panel
in a private compositor. Actual Wayland mouse events select each logo's custom
image option after closing and reopening the panel, browse and Apply separate
GIF/SVG files, replace an existing choice and cancel. The chooser must belong to
the current panel window. It also checks a full file path with spaces, `#` and
uppercase `.GIF`, independent fractional loop delays and constant switch labels.
It also checks cooldown unit conversion, independent values and timing resets.
Run at 100% and 200%; screenshots include the format help and preview.
The bar fixture waits for asynchronous preference saves before testing gestures
that depend on the new setting; a save request alone is not a settled UI change.

`bar-compact-native --desktop` loads the installed Omarchy Bar, including its
ModuleSlot click routing and transparency gesture, with a fictional registry and
settings owner. `--bar-section left|center|right` chooses the test placement.
It exercises the production WindowPeek widget and layer panel:
single-click pinning with hover disabled, a Qt double-click sequence, collapse,
Escape, later-click dismissal, and the unchanged default opening behavior.
It first sends an actual Wayland double-click to the bar, with a 30 ms gap, so the
second click tests compositor hit-testing after the compact panel maps.
It also requires intermediate expansion frames from a freshly pinned panel for
both bar and header double-clicks, and immediate expansion with animations off.
An actual Wayland bar double-click also collapses the expanded panel through
intermediate frames; the compact panel must stay pinned beyond the click timer.
Widget double-clicks must not change bar transparency, while empty bar space
retains its gesture. Hover opening and double-click promotion are also checked.
With pinning disabled, real bar clicks and bar/header double-click collapse must
leave a passive compact view; real pointer exit closes it. Check explicit compact
opening with hover opening disabled, re-enabling pinning, releasing an existing
pin, and contextual bar-name hints below the panel without background overlap.

After the 2026-09-22 compositor crash, native acceptance used a private nested
Hyprland session inside bubblewrap, with a headless output, private runtime
sockets and fictional input. The user's desktop was not connected. Qt software
rendering validates layer/input/geometry behavior, not GPU blur/grain appearance.
The hover fixture uses an ordinary background window to check keyboard ownership
and restoration. An additional exclusive layer would compete with the tested
panel and misrepresent normal application focus.

`tools/test_keybind_handles.py` uses actual Hyprland Lua handles in isolated
`--verify-config`, without starting a desktop. It checks partial and full expiry,
renewal, release, timer callbacks and reinstall for all three binding families.
Timers are simulated because config verification has no event loop.

`logo-cooldown` checks first playback, static rapid reopening, independent logo
slots, shared history across monitor instances, GIF and pixel playback, zero
cooldown, expiry and hidden-window lifecycle. `outside-wheel-native` uses a real
Wayland scroll receiver behind the production Bar/panel to check that the first
outside wheel event reaches it in compact, expanded and Settings/dropdown modes;
outside button presses still dismiss the panel. It covers right-click section
hierarchy, Move-menu pass-through, keyboard opening with the pointer outside,
and the very first wheel event without intervening pointer motion. Run both UI
scales privately. Expired-handle checks include the outside-input observer.

### Search focus and Pictures and Gifs

`search-focus.test.cjs` verifies restoration of every follow-mouse mode, lease
expiry, stale owners, external changes and config reload. The native
`outside-wheel-native` case checks typing after an outside wheel, mouse return
without scrolling Settings or Pictures and Gifs, and existing bar/menu dismissal.
`hover-navigation-native` covers rapid compact typing, expansion, continued
search outside the panel and keyboard release after closing.
`logo-picker-native` opens Pictures and Gifs from Personalization, picks independent
files, changes shared seconds/minutes, resets the duration and returns one level.
`logo-cooldown` covers both directions of shared suppression between built-in and
GIF logos, reopening, expiry, independent-mode restoration and a shared zero delay.
These native cases run in the private compositor at 100% and 200%.

### Search focus outside the compact and expanded panel

`pinned-search-native` uses the production bar/widget and a separate fictional
application process. Four compact exit/return cycles must release keyboard focus
within 400 ms and regain it by hover alone, without clicking. Right-arrow input
must reach the background application while the compact panel is inactive. Two
motion frames cross Hyprland's movement threshold after an idle interval.
Typing then promotes with the full query and retains it while filtering shrinks
the panel above a stationary cursor. Further checks cover outside typing, an empty
Search, preview dismissal, and continued typing after crossing empty desktop space.
Double-click collapse must restore prompt compact handoff; an outside click closes it.
The new handoff assertion fails against the prior runtime and passes at 100%/200%.
A private comparison with two real Foot processes and a fictional tiled X11 resize
source also verifies hover-only return and immediate release; it stores no user
terminal content. Logged event timestamps are not physical display latency.
Run at 100% and 200%; pair with `outside-wheel-native` to verify wheel pass-through,
settings scroll retention and restoration of the runtime focus preference.
The status IPC exposes focus booleans and the panel mode without recording the
search text or window titles.
These checks cover normal pointer motion; they do not establish immunity to
compositor-forced focus changes. In Hyprland 0.56.2, adding a tiled X11 client
that repeatedly calls `XResizeWindow` reproduces a failure after the panel
shrinks beyond the cursor. Keep that case separate from the passing Wayland
baseline when validating a plugin-side workaround.

The private compositor comparison used the same fictional X11 application
requesting alternating widths every 250 ms. No real launcher is required.
Results on Hyprland 0.56.2 at 100%:

| Panel focus policy | X11 window mode | Typing outside the panel | Outside wheel |
| --- | --- | --- | --- |
| Current OnDemand and follow-mouse lease | Tiled | Fails after filtering shrinks the panel | Not evaluated in this run |
| Current OnDemand and follow-mouse lease | Floating | Passes | Not evaluated in this run |
| Exclusive while searching | Tiled | Passes | Fails: underlying application receives no scroll |
| OnDemand with HyprlandFocusGrab | Tiled | Fails after filtering shrinks the panel | Not evaluated in this run |

These are diagnostic variants, not enabled production fallbacks. A future fix
must pass both typing and outside-wheel tests with the tiled X11 client still
sending requests. Also check normal dismissal, window selection, previews,
multiple monitors and cleanup on close, reload or shell exit. A pass obtained
by floating or stopping the sender is a control case, not proof of a plugin fix.

For compositor revisions containing
[Hyprland #15899](https://github.com/hyprwm/Hyprland/pull/15899), repeat the
Exclusive variant with the normal card input region and no wheel replay.
Test the application active before opening the panel separately from another
application under the pointer: forced refocus can take different internal
paths. Keep the X11 request sender running in both cases. A separate native run
of unmodified commit 23118f9f confirmed exact first/second wheel delivery but
lost keyboard focus over the previously active application at both 100% and
200% UI scale. A different target retained focus; removing the X11 sender also
passed. The 200% run used an actual pointer-v7 receiver. Outside dismissal
passed in each case. The original table above remains the 0.56.2 comparison.
Verify keyboard and original pointer delivery together, including dismissal
and owned popups, before selecting a future fix by version or capability.

A separate diagnostic compositor build removed only the rejected X11 request's
`refocus()` call, preserving its geometry reply. The unchanged OnDemand panel
passed the same-target tests at 100% and 200% (pointer v7), and a different-target
test at 100%. The Exclusive variant also passed at 100%. The unmodified-build
control still failed outside typing. All runs kept the X11 sender mapped and
verified it received synthetic ConfigureNotify replies. These are focused
reproducer results, not a general regression certification or a shipped fix;
the patched stable 0.56.2 base, real RSI, multiple monitors, fullscreen and
interactive window dragging were not tested.

A separate plugin-API prototype used a card-sized native toplevel with
`stay_focused`, synchronously releasing its own property from a non-consuming
Lua wheel callback. On unmodified 0.56.2 it passed ordinary-wheel checks at
100% and pointer-v7 checks at 200%. Negative cases failed: rapid scrolling from
inside to outside with the default 300 ms binding delay, a configured 2000 ms
delay, and FINGER events. FINGER was verified from axis_source=1 in the receiver's
protocol log; a virtual-pointer test must send axis_source after axis on this
version, which otherwise overwrites the source. Do not treat a WHEEL event
merely labelled as a touchpad test as evidence. This prototype is not enabled.
No-X11 controls on stable 0.56.2 also failed rapid-wheel and FINGER delivery.
The ordinary-wheel control passed packet comparison, retaining keyboard focus
in search after scrolling. Distinguish query loss from a test expecting keyboard
handoff: `de` in search instead of `d` in search and `e` in the receiver means
focus stayed with the panel. Include unaffected clients in fallback regression
tests; the presence of an RSI window is not proof that the focus bug is active.

The subsequent temporary-own-window prototype passed the same-target focus and
pointer contract on unmodified upstream `23118f9`: 100% wheel, 200% pointer v7,
and a synthetic FINGER axis. Its control without the temporary window failed
typing; stable 0.56.2 with it still failed scrolling. The log must prove that the
temporary window was focused, unmapped and destroyed before outside typing.
These are bar-opening tests, not keyboard-opening or full lifecycle coverage.
Any further implementation must test opening with the pointer already over an
application, repeated opens, focus history and removal from window inventories.

A separate on-key-refocus test on 0.56.2 failed outside typing even though the
raw Wayland trace showed the original key reaching the plugin. Its no-X11
control passed. Protocol delivery alone does not prove text-field editing;
assert actual text, composed input and held-key repeats as well.

If a fallback yields keyboard focus when scrolling outside the panel, verify
that the first wheel event reaches the application exactly once and at its
original amount. Include rapid bursts, direction changes, horizontal scrolling,
touchpad input, modifiers, global and per-device scroll factors, and per-window
scroll overrides. Verify the actual application input, not just a successful
forwarding command. The query must survive the handoff, panel shortcuts must be
released, and returning the pointer alone must not reclaim the keyboard; an
explicit panel click can resume typing. Consuming the first wheel event does
not meet this requirement.

Measure a direct scroll with the panel closed as the reference for each factor
combination. Include an explicit window override equal to the global factor and
the same configuration without that override: their public property readouts
can match even though their effective scroll behavior differs. Also cover
factors with more than two decimal places and source-device observation skipped
by `binds.scroll_event_delay`; stale source metadata must not silently select a
replay factor.

Compare protocol events as well as Qt deltas. A source factor of 2, replay
factor of 1 and no window override is a required counterexample: replay can
match `axis_value120=240` while changing continuous `axis` from 30 to 15 and
legacy `axis_discrete` from 2 to 1. Test an actual receiver bound to pointer
version 7 as well as version 8 or newer. A modern-Qt-only pass does not establish
equivalence. Check source, both axes, stop/frame boundaries and discrete values;
exclude delivery timestamps from amount comparisons. Include small wheel
increments with `input.emulate_discrete_scroll` both enabled and disabled, and
compare the following physical events to detect changes to its shared
accumulator. Keep a uniform-factor full-notch control that should pass.
See [the cause and rejected approaches](ARCHITECTURE.md#x11-resize-requests-and-keyboard-focus).

### Focus-incident policy

`node --test tests/focus-incident.test.cjs` tests the experimental detection and
consent core. It is included in `tools/check.py`. Coverage includes ambiguous or
stale source identities, ordinary geometry changes, intentional navigation,
focus recovery, source removal and consent expiry. Approval follows the exact
problematic window across panel openings, with protection inactive while the
panel is closed. Confirmed source closure emits one notification; stale/failed
inventory and reused window identities are tested separately. Detection alone never grants
permission. `FocusRecovery.qml` connects this policy to the native panel.

`tests/fixtures/focus-incidents.json` contains relative event times from four
isolated native runs on unmodified Hyprland 0.56.2. It uses fictional window IDs
and includes no real window titles or input. The replay offers one incident for
the tiled resize reproducer and none for: no X11 sender, a floating sender, or
an intentional focus dispatch while the tiled sender remains active. The
floating/tiled labels are known fixture inputs, not validation of a runtime
classifier. A separate XRes probe verified that its PID matched Hyprland's PID
for the fictional window.

`tests/x11-focus-source.c` reproduces a managed resize source with seven unmapped
helper windows sharing its PID/class. It refuses to run outside the private
test environment. Compile it with `cc -O2 tests/x11-focus-source.c -lX11 -o SOURCE`
and launch it inside the isolated compositor. Repeat the recovery flow after
moving only the source to another workspace; verify it remains mapped and its
workspace differs from the focused receiver's workspace. The managed-client list must contain only its real window, and the
passive notice must still appear. Two actual managed windows sharing PID/class
must remain ambiguous. This covers helper-window and inactive-workspace cases
that a single visible test window cannot exercise.

The private observer selected only `StructureNotifyMask` on the fictional X11
client. Repeated synthetic unchanged-size replies were observable without
intercepting input. Native Qt activation supplied the actual loss transition;
Hyprland's `window.active` event was absent at the reproduced forced loss.
Intentional dispatch supplied a reason that correctly excluded its control.

These policy tests alone validate the policy and feasibility of its signals. They do not establish false-positive rates on real
desktops, Wine PID mapping, complete input/lifecycle exclusions, or safe fallback
scrolling. See [the integration requirements](FOCUS_RECOVERY.md).


### Native recovery and second-monitor hover

The isolated native integration tests use an unmodified Hyprland 0.56.2 and
fictional receiver/resize-sender windows. They exercise the actual bar widget,
passive observer, real clicks on Review/Enable, native panel mapping, typing
outside the panel, original first/second wheel packets, outside dismissal,
reopening with consent, and automatic revocation with one notification when the
source process closes. The positive flow passed at 100% and 200%. Controls cover
absence of an X11 source, a floating source, and declining the dialog.
These cases require a private compositor with a fictional X11 resize sender;
they must not be aimed at a user's real application.

`hover-stability-native.qml` observes compact-open transitions, not just backing
window mapping: a fade can stay mapped throughout repeated dismiss/reopen loops.
Two outputs at x=0 and x=1920 reproduced 23 dismissals under a stationary pointer.
The fixed test checks stable hover, Esc suppression and real exit/reentry.

### Persistent focus protection and Troubleshooting

`focus-settings` checks the nested Controls entry, one-level Back, explicit
on/off changes, and a passive suggestion that opens only the explanation. Run at
100% and 200%. Widget and preferences tests cover default-off behavior, monitor
synchronization, failed writes and loading the choice in a new process.

`focus-settings-native` requires `WINDOWPEEK_ISOLATED=1` and a private compositor.
Run on unmodified Hyprland 0.56.2, with and without the fictional X11 sender, at
100%/200%. It tests real bar clicks, outside typing from pinned compact search,
outside WHEEL and fractional FINGER/axis-stop packets (none delivered to the
receiver), an overflowing inside list, outside dismissal, restored normal wheel
input, repeated openings, source closure, Settings releasing the hold, deliberate
on/off changes, bounded recovery after actual lease expiry, and an explicit Retry after repeated failures.
The outside click is required to dismiss; the test does not promise forwarding
that dismissal click to the receiver. All application windows are fictional.

With `WP_CASE=suggestion`, the native fixture disables only its optional X11
observer, reproduces three distinct actual focus losses in expanded Search, and
checks a generic suggestion with no attribution, grant or automatic setting change.
Reopening only the compact panel must not show that reminder; expanding Search
can show it again. The pure
interruption tests cover duplicate polling, intentional transitions, expiry,
foreign sessions and a 30-minute suggestion mute after opening the explanation.

Retest `focus-recovery-native` to preserve the separate temporary-consent flow,
including its wheel-triggered yielding. No host pointer/input test is implicit
in any offline check or build.

### Click recovery after native keyboard focus loss

`focus-click-native` requires a private compositor and a fictional tiled X11
resize sender. At 100% and 200%, it checks the reproduced focus loss, hidden caret,
real field and blank-panel clicks, and text sent immediately after each click.
Only the search may receive those characters. Repeat loss and recovery without
silently enabling protection or reacquiring focus automatically. Outside scrolling
must still reach the receiver, the query must survive, and Esc must dismiss.
After a real loss, move between both background windows while leaving Search
open: each focus transition must take less than 400 ms, without waiting for the
synthetic resize sender's next 1.5-second burst. Use two motion frames to cross
the compositor's movement threshold after idle, rather than a lone cursor warp.
The pre-fix implementation shows a focused field but sends the next key to the
background receiver. The test exercises real keyboard delivery, not just Qt focus
flags, and must never target a user's applications.

### Help after a dismissed or unattributed interruption

`focus-notice-native` uses a private compositor and fictional applications. It
first loses keyboard focus in the pinned compact panel without producing any
warning, pending loss or repeated-loss count. Clicking the header reacquires focus;
explicit expansion then opens empty Search. Only a fresh loss offers help.
The test reviews/declines advice and opens Troubleshooting to mute repeated
suggestions. It then opens expanded
search by a real bar double-click, types a query that shrinks the panel, and loses
focus again. The new loss must still show Review options without enabling any
protection. Its click must open the general explanation. Run at 100% and 200%.

`WP_CASE=unknown` disables only the optional X11 observer after opening and types
the first character in compact mode to expand Search. That character must survive,
and a fresh loss in expanded Search must offer help without identifying an application.
`tests/x11-focus-source.c --floating-companion` additionally maps a small managed
dialog of another class alongside the tiled resize source. The native fixture
checks that it really is floating before exercising both panel modes. These
fixtures require `WINDOWPEEK_ISOLATED=1`; never use a real user's application.
The existing `focus-settings-native` suggestion case also verifies first-loss
status while retaining the separate three-loss threshold for stronger advice.

`focus-geometry-native` is restricted to a private compositor and fictional
windows. Real key presses alternate matching/empty searches five times; actual
pointer double-clicks on the panel header collapse and expand it. The fixture
samples compositor window positions during these changes and checks settled
window sizes against the visible card, so freezing the native window cannot pass.
Run at 100% and 200%. Its default is persistent strict protection; `WP_CASE=temporary`
instead requires the fictional tiled X11 resize source, detects the incident and
clicks through temporary consent before the same geometry checks. A fixed 12×12
pixel green marker supports independent compositor-output checks for stretching.
On unmodified Hyprland 0.56.2 the old equal min/max constraints reproduced a
46-pixel positional jump; resizing and anchoring in one callback removed it.

`focus-close-native` also requires a private compositor. It opens the real panel
with strict protection, or detects a fictional X11 incident and clicks temporary
consent with `WP_CASE=temporary`. `WP_TARGET=outside` closes by a real outside
click, `row` clicks an actual row and verifies the final active window, and the
default sends Esc. `bar` invokes the bar button handler including its click-delay
timer; it does not claim to test compositor routing to the bar. Samples require
monotonically decreasing opacity and native ownership until the card is invisible,
then complete unmapping and released native-rule ownership. Run with compositor
animations enabled, at 100% and 200%, so early rule removal is not masked.

`focus-return-native` tests a fresh expanded search without any old notice or
repeated-loss suggestion. It clicks Search and immediately exits over another
window, or (`WP_TWO=1`) crosses to another monitor and back without clicking.
The fixture requires actual native focus loss and a new visible help action;
protection must stay disabled until consent. With `WP_CASE=control` and no X11
source it requires retained focus and no notice. `WP_CASE=intentional` instead
uses an explicit focus-window dispatcher and requires no interruption notice.
All these variants are guarded to run only in a private compositor.

`focus-protection-cycle-native` requires two private outputs (`WP_TWO=1`) with
a fictional receiver on each. `WP_TARGET` selects the reproducible shuffle seed
(default 7). It uses real keys and pointer events to mix search typing, crossing
monitors, closing/reopening on either bar, compact/expanded header and bar clicks,
wheel yielding and resumption. Every typed character must reach Search and none
may reach either receiver. Bar clicks must toggle exactly once without pausing
protection. The baseline failed bar double-click at 200%; the corrected path
passed with seeds 7/17 at 100%/200%, alongside temporary and strict-mode controls.

The mixed test also checks passive preview visibility and selection by clicking
the native preview surface. `--placeholder-preview` replaces only the captured
image in its isolated plugin copy, preserving real panel/popup surfaces and input.
This separates input regressions from software screencopy stalls; it is not proof
of live capture performance. Verify real capture separately on the installed bar.
The strict native test expires the actual compositor lease twice and requires
bounded recovery without resetting the preference. A third expiry releases
protection and reports once; Retry is explicit. Late events from an older lease
must not cancel the recovered one.

### Focus explanation layout

`focus-settings` checks that Troubleshooting starts at the explanation, opening
help does not enable protection, review dismisses an existing preview, underlying
controls are hidden and the dialog preserves the enclosing background. Run at
100% and 200%, also with `--style compact`. With `--image /absolute/path/name.png`,
it saves introduction, protection, warning and dialog views with filename suffixes.
`focus-issues --image /absolute/path/history.png` also captures the local app list.
Native `focus-recovery-native` covers explicit approval and the ignore/restore path
in the private compositor; do not run its focus-stealing fixture on the real desktop.

The review tests also cover unidentified and repeated incidents, retained search
and list scroll, and return routes through review, directly to the list and
through Settings. `navigation` distinguishes Back (leave the editor, skipping
its inner section) from right-click (close the nearest inner level), and checks
reverse section-opening order independently of pointer position.

`settings-visit` verifies pixel/GIF playback across submenu visits: pause and
resume without rewinding, completed single-play animations remaining completed,
remaining loop delay, and cooldown on a new Settings visit. Existing
`logo-playback`, `logo-cooldown` and `branding` cover the other logo behavior.

The short review also tests enabling recurring protection directly, without
opening Settings, and a failed save leaving the dialog open with protection off.

`focus-close-native` samples the protection status during fade-out alongside
opacity and native-surface ownership. The status text and row must remain stable
until invisible, while the keyboard lease is still released on close.

`focus-approval` exercises independent reader timing: stale XRes on the first
compositor reply, late XRes requiring another compositor read, changed identity,
cancellation, panel closure and bounded timeout. One user approval must suffice
when valid fresh samples arrive, without granting from stale or changed evidence.

`focus-close-native` with `WP_TARGET=toggle` checks enabling and disabling
protection while Search remains open. It samples a synthetic marker through
compositor screenshots with compositor animations enabled, and checks that
neither the open state, opacity nor search text resets. `WP_CASE=temporary`
starts with consented temporary protection and clicks Turn off. The frame probe
requires the private compositor and stores no desktop images.

`focus-close-native` with `WP_CASE=review WP_TARGET=outside` dismisses the
short mitigation review with a real outside click. Throughout fade-out it requires
the review to remain visible with the same height and action list, then fully
unmap without showing Search. Run at 100% and 200%.

`focus-recovery-native` with `WP_CASE=stop` checks Turn off, reopening the compact
panel, entering Options and approving temporary protection again, followed by
animated expansion. `WP_CASE=first-expand` detects an interruption in visible Search,
collapses the panel, then expands immediately on consent to
exercise overlap with native surface setup. Expansion must not advance while its
surface-transfer snapshot is displayed; rendered intermediate sizes are required.
`focus-approval` also checks reapproval against fresh identities and removal of
the stopped offer when its source closes.

### Text shadows and unattributed focus interruptions

`text-readability.test.cjs` covers contrast estimates for light/dark text,
transparency, row backing and explicit overrides. `text-shadow` exercises the
actual local wallpaper sampler, manual choices, live wallpaper changes and native
button labels. It checks that adding the shadow does not change text dimensions. Green-theme
compact captures verify that the count uses solid text and a raised shadow, not
a surrounding outline. Contrast tests cover faint ink and restoration with Off.
`focus-settings` covers temporary approval when attribution is unavailable and
ensures warning text has no background block. Preferences checks retain the
manual shadow choice across a process restart.

The private `focus-recovery-native` fixture with `WP_CASE=unknown` withholds source
attribution while reproducing a real keyboard interruption. It checks explicit
approval, outside typing and scrolling, consent across close/reopen, manual
switch-off and reapproval, and survival when an unrelated source window closes.
No permanent preference or guessed application identity is introduced.

`readability-coverage` checks preview captions, reparented hints, file/shortcut
popups, dropdown search and native input fields with On/Off/Automatic. It checks
the actual Search placeholder, typing and selection replacement. Run at scales
1 and 2; `--placeholder-preview` substitutes a fictional captured image.

`bar-readability` clicks the native bar button and verifies active/inactive text,
opaque/transparent backgrounds, preserved label width and On/Off/Automatic.

`readability-worker` verifies that a thousand labels with the same colors share
one worker job, compares its result with the pure contrast policy, rejects stale
sample generations, applies explicit On/Off immediately and bounds retained color
roles. `text-shadow` also checks reuse of previously sampled wallpaper crops.
These are policy and lifecycle checks; they do not measure compositor presentation
or establish smoothness of panel and preview animation.

`hover-navigation` also checks that prepared native hover bindings follow edits
made while expanded, remove the old chord, and update direction-sensitive actions
when switching to an RTL language. Expanded mode still releases hover bindings.


### Performance regression coverage

`window-state` verifies that geometry-only snapshots retain the list model while
raw focus diagnostics, revisions and timestamps remain fresh. List-relevant
changes and error/recovery still update the UI. `widget` covers queued edits and
shared hint-budget reservations from both monitors. Preference failure/retry
checks wait for durable asynchronous completion rather than assuming enqueue
means saved.

`readability-worker` checks shared roles, stale replies, explicit choices and a
bounded cache. The pure readability suite compares the process worker with the
JS policy over 576 deterministic combinations of backgrounds, text/backing alpha
and modes. Native fixture exit must also succeed; a pass marker followed by a
crash is a failure.

The native capture suite samples every reported frame during repeated expansion
and collapse. It verifies the same capture and owner, a shared surface, a visible
preview and a stable scaled edge gap, as well as intermediate widths when animation
is enabled. Keep timing benchmarks separate from functional tests: running other
CPU-heavy fixtures concurrently can distort CPU and frame measurements.


`readability-opening` opens two independent panel owners with a real delayed
wallpaper sampler. It checks that secondary text never reverts to dim ink while
the first crop is pending, including cached reopen after worker shutdown and a
wallpaper change. Run at scales 1 and 2. `--image` optionally saves snapshots of
fictional labels; no live window data is read.

`focus-protection-cycle-native` with `WP_CASE=motion` exercises four protected
animation cases on two private monitors, with and without preview. Frame samples
assert a shared render surface, a fixed native viewport, and ongoing animation.
Repeat with `WP_TARGET=permanent` for Keep search focus; the default uses temporary
consent. Both assert that a passive visible preview does not release protection.
The normal mixed cycle separately checks text delivery, outside-wheel release,
preview clicks, closing, reopening, and returning between monitors.

`focus-close-native` with `WP_CASE=temporary WP_TARGET=clear-outside` covers typing
into a protected compact panel, clearing Search, then closing outside. The
expanded presentation must remain unchanged throughout fade-out. Mixed protected
cycles also check delivery of the full first outside wheel event; permanent-focus
checks cover blocked wheel/touchpad input, allowed Settings scrolling and clicks.

`motion` exercises both the standalone animation and the window-driven clock:
mid-flight reversal, immediate disable, pause/resume, terminal values, no idle
frame requests, and completion after the presenting window is hidden or detached.
For cadence measurements, use compositor presentation timestamps and collapse
consecutive identical widths before comparing intervals. `frameSwapped` alone
does not prove that distinct widths reached the display. Record CPU time separately
from elapsed render/submission time to distinguish computation from waiting.
