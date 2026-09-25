# Known Issues

The remaining limitations are listed first. The lower-refresh-rate resizing and
wallpaper readability problems are [fixed in 0.7.2](#fixed-in-072).
For short, practical guidance, see [Troubleshooting](TROUBLESHOOTING.md).

## Typing is redirected when another application requests a window resize

**Status:** Reproduced on Hyprland 0.56.2; optional protection has trade-offs

### Symptoms and conditions

Typing in WindowPeek can stop reaching Search and go to the application under
the pointer instead. It can happen when moving the pointer outside the panel,
including when filtering shrinks the panel beneath a stationary pointer. Moving
over empty desktop space did not trigger the same loss in the reproduced case.
Ordinary compact browsing now follows the user's mouse-focus settings, so moving
from it to another window is expected to release input and does not warn. Typing
in the compact panel expands Search, where the retention issue can still occur.

The confirmed trigger is a **tiled X11 application repeatedly asking to change
its window size** while search owns the keyboard. Wine applications can use this
path, but this is not limited to Wine or a particular launcher. A fictional X11
application reproduces it too. The requesting window can be on another workspace
and need not be the window that receives the typing. Simply running an X11
application does not mean it is causing a problem.

### Cause and detection limits

In the affected Hyprland version, the
[handler for X11 size requests](https://github.com/hyprwm/Hyprland/blob/efb50993780079460b0cbed1363e2166a2de1d9f/src/desktop/view/Window.cpp#L1544-L1563)
rejects the requested size for a tiled window, then forcibly re-evaluates focus
under the pointer. This can take keyboard input away from a panel even though
its text field still considers itself focused. The same loss was reproduced in
an independent panel without WindowPeek running.

WindowPeek detects unexpected keyboard loss while expanded Search is visible
(including after typing expands the compact panel) and, where possible, correlates it
with repeated X11 size replies and a uniquely identified window. This is evidence
of a **suspected source**, not proof of blame. Ambiguous identities or other focus
problems may produce an unidentified interruption. The detector does not use a
list of application names. Other compositor versions have not been established
to behave identically.
Simply browsing a pinned compact panel does not trigger an interrupted-typing warning.

### What users can try

- Give the requesting window more room. If it is trying to fit its contents,
  a larger tile may stop the repeated requests. This is a reported observation,
  not a guaranteed fix or a measured minimum size.
- Switch that application to an ordinary floating window. This avoided the
  reproduced tiled trigger. Fullscreen is a different state and is not covered
  by that result.
- Close the requesting window when it is not needed, or try the application's
  documented native Wayland mode if it supports one.
- Choose **Review options → Enable temporary protection** after an
  interruption. Protection holds typing in WindowPeek; outside scrolling pauses
  it, and touchpad or rapid wheel input outside can be lost. Closing an identified source
  window ends this permission automatically. If the source is unknown, protection
  lasts until you turn it off or restart the bar, including across panel reopenings.
- For frequent interruptions, consider **Settings → Controls → Troubleshooting →
  Keep search focus**. It applies on each search opening and blocks scrolling
  outside the panel, including touchpads. Click outside or press Esc to close.

These choices do not replace Hyprland or change its configuration files.
WindowPeek does not automatically resize, float or reconfigure other applications.
Neither protection mode should be treated as a repair of every focus problem.

### Ignoring warnings and reviewing applications

**Ignore warnings** in the notice offers three scopes:

- **Until logout:** lasts for this Hyprland session, including bar restarts;
  logging out or restarting Hyprland ends it
- **This app:** persists for the identified X11 application class, including
  newly opened windows; applications sharing that class share the choice
- **All focus warnings:** persists until switched off in Troubleshooting

Ignoring only hides warnings. It does not prevent the interruption or enable
protection. An application ignore applies only when the detector can associate
that interruption with the application; it does not hide unrelated or
unidentified losses. Protection status and failure notices remain available.

**Settings → Controls → Troubleshooting** lists applications associated with
observed incidents, their identity, last detection and recorded incident count.
Each entry lets users ignore or restore warnings. Session and global switches
are on the same page; they can still mute an individually restored app. Detection
can continue adding records while warnings are muted. This list is a place to
review suspected sources, not an automatic mitigation allowlist.

History is stored locally in `~/.local/state/windowpeek/focus-issues.json`
(or under `XDG_STATE_HOME`). It contains application names/classes and incident
metadata, never window titles, keystrokes or search queries. At most 256 entries
are retained. Saved ignore choices are not silently evicted to make room.

### Reproducing or reporting this issue

With protection off, open Search while a tiled X11 window repeatedly requests
another size, then move the pointer over another application. Compare with more
room for the requesting window, with that window floating, and with it closed.
Use harmless test text and check which application receives it.

Include compositor version, the suspected app and whether it uses X11/Wine,
tiled/floating state, whether more room helps, and whether **Review options**
identifies an app. Do not assume the window receiving keystrokes caused the loss.
See [focus recovery](FOCUS_RECOVERY.md) and the
[technical investigation](ARCHITECTURE.md#x11-resize-requests-and-keyboard-focus)
for the evidence policy and protection limits.

## Animation cadence on high-refresh displays

**Status:** Remaining limitation; smoothness is not a guarantee of one update per refresh

After the 0.7.2 animation fix, the tested 239.76 Hz display recorded median
intervals near 8.34 ms between distinct panel widths, with some intervals of
12.5–17.1 ms. This is better than the earlier approximately 16 ms cadence, but
does not establish a distinct width update on every 240 Hz refresh.

Qt's render loop, the compositor and graphics driver can affect frame pacing.
See [Qt's rendering documentation](https://doc.qt.io/qt-6/qtquick-visualcanvas-scenegraph.html)
and a related [Omarchy report](https://github.com/omacom/omarchy/issues/7268).
These do not identify the render-loop mode of every affected setup. WindowPeek
does not change shell-wide renderer settings, monitor refresh rates or VRR.

## Fixed in 0.7.2

### Choppy resizing with a visible window preview

**Status:** Fixed in the plugin; verified on the affected 60 Hz display

Older code could stutter when expanding or collapsing with a live preview,
particularly at 60/75 Hz. The problem also reproduced on the first monitor after
lowering its refresh rate, so it was not specific to a second monitor or workspace.
At 120 Hz, a repeat showed only slight visible stutter. These observations describe
the old code; the final fix was not separately remeasured at 75 or 120 Hz.

Three separate costs were addressed:

- **Moving a separate preview window:** the panel and live preview now share one
  render surface. Moving the preview previously triggered extra Wayland window
  updates and frame-synchronization waits. Keeping its image static did not help;
  the fix retains live capture and keeps the preview attached to the panel
- **Resizing the protected native window:** both protection modes now use a stable
  transparent viewport. The visible card and preview animate inside it, without
  resizing the native window on each frame
- **Animation timing:** expansion and collapse calculate progress immediately
  before the presenting window draws. This also fixes the separate case where
  otherwise identical states alternated between smooth and choppy motion, with
  or without preview and with Review options visible

The main cause identified in the old preview path was extra window movement;
Qt frame synchronization is the leading explanation for the measured waiting.
See Qt's [configuration handling](https://github.com/qt/qtbase/blob/v6.11.2/src/plugins/platforms/wayland/qwaylandwindow.cpp#L720-L742)
and [frame synchronization](https://github.com/qt/qtbase/blob/v6.11.2/src/plugins/platforms/wayland/plugins/hardwareintegration/wayland-egl/qwaylandglcontext.cpp#L459-L498).
The complete upstream call sequence was not traced on the affected desktop.

The final 60 Hz comparison used 96 rapid double-clicks per version, alternating
preview on/off without closing the panel or pausing after hiding preview.
Review options was visible, protection was off, and VRR was disabled in both runs.
Compositor timestamps recorded **67 intervals above 25 ms before the animation
change and none afterward** across eight series. The final three pixels near
endpoints were excluded because easing and integer rounding can repeat widths.
CPU load was similar; render-submission waits still occurred after the fix.

Separate protected-panel tests verified a fixed viewport and an attached live
preview at an 8-logical-pixel gap. The final protected 60 Hz run reported mixed
refresh intervals, so it does not establish perfect physical presentation cadence
for that path. Functional regressions cover both protection modes, preview on/off,
two monitors and 200% interface scale.

Verified environment: Omarchy 4.0.4, Hyprland 0.56.2, Quickshell 0.3.1,
Qt 6.11.2 and NVIDIA 610.57.04. Results do not guarantee perfect motion under
every workload or on every driver. No screenshot mode, paused preview or
compositor patch is required by the fix.

If stutter remains in 0.7.2, include your versions, GPU/driver, each monitor's
resolution/refresh/scale, protection mode and whether preview is visible. Compare
several rapid expansions and collapses within one open panel, immediately after
hiding preview. Distinguish panel resizing from a shake on initial preview
appearance; the latter has not been confirmed to share the same cause. Do not
include private window titles or preview contents in a report.

### Pauses while wallpaper text contrast is recalculated

**Status:** Fixed

Automatic readability previously rescanned wallpaper contrast for many labels,
including hidden controls. A measured update performed about 1,280 scans and
blocked the UI for 227–262 ms. Close interactions could overlap that work with a
transition; this did not explain every reported animation jump.

Contrast decisions now run in a helper process, with shared color decisions and
cached wallpaper crops. Hidden controls skip this work and hidden Settings retain
their layout width during animation. The panel stays usable while results arrive;
stale results are discarded.

### Text briefly darkens on the first panel opening

**Status:** Fixed

On a wallpaper background, secondary text could briefly dim on each monitor's
first opening, then recover when wallpaper samples arrived. Missing samples were
incorrectly treated as the plain panel tint. The fix keeps readable initial text
until the actual wallpaper is analysed asynchronously. Samples from another
wallpaper cannot replace it. Text shadow → Off still restores the original text.

Regressions cover cold opening, cached reopening, wallpaper changes and
100%/200% interface scale.
