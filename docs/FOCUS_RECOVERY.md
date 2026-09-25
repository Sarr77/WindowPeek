# Detecting interrupted search

Status: implemented as an experimental, opt-in recovery mode. The passive
observer is active while an opened search or pinned compact panel is in use,
but only visible, expanded Search can produce a new interruption warning.
Temporary, source-specific protection never starts without a detected incident and
an explicit confirmation. A separate, persistent **Keep search focus** setting is
opt-in and does not require identifying an application. Recovery and Troubleshooting
explanations currently have English and Polish text; other languages use English.
The Troubleshooting entry is translated in all 30 interface languages.

Hyprland 0.56.2 can move keyboard focus away from search when a tiled X11
application repeatedly requests a new size. The [focus investigation](ARCHITECTURE.md#x11-resize-requests-and-keyboard-focus)
describes the cause and tested alternatives. Merely having RSI Launcher, Wine
or another X11 application open must never enable a workaround.

## Returning to interrupted search

Without opt-in protection, only expanded Search retains keyboard input outside the
panel, including with an empty query. Compact browsing follows the user's normal
mouse-focus settings; under focus-follows-mouse, leaving for another window releases
input and returning by hover allows typing again. The first character expands Search
and starts retaining focus. Compact navigation shortcuts also release on actual
keyboard loss. Previously approved protection keeps its own behavior in compact mode.

Clicking an inactive panel or its search field requests keyboard focus once and
preserves the query. It does not enable either protection mode. The caret is
hidden while the panel is not receiving keyboard input, even if Qt still marks
the text field as focused. Actual keyboard loss also releases the ordinary
search hold, restoring the user's mouse-focus mode immediately so an inactive
panel does not delay focus changes between other applications.
Focus loss alone never starts an acquisition loop;
the application may interrupt search again until the user chooses protection
or removes the trigger.

## Keep search focus

**Settings → Controls → Troubleshooting → Keep search focus** is off by default.
Consider enabling it when moving the pointer over another application repeatedly
interrupts typing in search. Leave it off when search works normally. It applies
to each opened search panel, including a pinned compact panel, until disabled in
Settings. Enabling it requires confirmation with its scrolling restriction and
the path to disable it. Ordinary permanent protection adds no status banner.
It does not pin passive hover panels or change their opening behavior.

This mode intentionally blocks outside scrolling, including mouse-wheel and
FINGER/touchpad events, while search holds focus. Inside scrolling remains usable.
Click outside or press Esc to close the panel; ordinary input then resumes.
Settings, transient menus and pointer interaction with a preview release the
strict hold. A passive visible preview does not release either protection mode. The preference
persists across restarts and is independent of any source window's lifetime.
Selecting it replaces an existing temporary source-specific grant, so disabling
it cannot unexpectedly leave that old protection active.

The implementation uses the same owned native window and short runtime lease as
temporary protection, with wheel-triggered yielding disabled. It does not edit
Hyprland configuration files, replace the compositor, intercept typed characters,
or repeatedly reacquire lost focus. Missing Lua support leaves normal input in
place. A backend failure releases the failed hold while preserving the preference or
window consent. Recovery is limited to two attempts per opening; after that, the
user can choose Retry or reopen the panel. This is a trade-off that blocks
outside scrolling, not a repair of touchpad forwarding or every possible focus bug.

The explanation lists the reproduced X11/Wine resize-request issue in affected
Hyprland versions and possible window-activation rules. It does not infer blame
from focus loss alone. Floating the affected X11 window, closing it when unused,
or using its documented native Wayland mode are optional alternatives.

## Interruption status and repeated suggestions

A settled unwanted loss of native keyboard focus shows **Typing in search was interrupted — Review options** even when no application can be identified. This
requires prior keyboard ownership and the same intentional-input exclusions as
the source-specific detector. It does not require any particular application,
X11 geometry evidence, or the optional X11 observer. Browsing a pinned compact
panel does not trigger a warning or count toward repeated-loss suggestions.
Its keyboard readiness still supports shortcuts and typing to expand Search.
After explicit expansion or the first typed character, a fresh loss can be
reported even with an empty query. Earlier compact losses are not replayed.
Passive hover is not tracked.

Without confident attribution, Review options opens the same brief explanation
without an application name, with a link to Troubleshooting. It does not enable protection. Reviewing or
dismissing advice acknowledges the current status; a later interruption can show
it again in expanded Search, unless explicitly ignored for the session, that identified app or all focus warnings.
Declining source-specific protection does not hide this later generic status.
An existing protection status and Turn off remain available in compact mode;
this detection limit does not remove previously granted protection or its controls.

Three separate, settled unwanted focus losses within two minutes may suggest
considering the persistent setting more explicitly. This counts
native focus transitions while search is eligible; it does not count repeated
polls of a single loss. Intentional input/navigation, initial acquisition, menus,
previews, short self-recovered losses and foreign sessions are excluded. Detection
still works when the optional X11 observer is unavailable. The count is memory-only
and contains no application names or search text.

The suggestion is passive. Its button opens the explanation and does not enable
anything. Opening that explanation suppresses repeated-loss suggestions for
30 minutes, but not a new interruption's status and access to help.
The separate, stricter evidence below remains necessary for a source-specific
prompt and grant. Neither the suggestion nor the X11 heuristic is a guaranteed
cause detector.

## Evidence

The policy requires a previously focused search panel to lose native keyboard
focus while it remains eligible for search. It correlates this with at least
three synthetic X11 geometry replies for the same unchanged size, spread over
at least 300 ms within the last two seconds. This includes separated short
bursts, not just steady requests. A reply must be within 200 ms of the loss. A 200 ms settling
period allows intentional navigation to cancel the candidate.

An independent X11 connection can observe `ConfigureNotify` using
`StructureNotifyMask`. It neither consumes mouse/keyboard events nor receives
typed text. The compositor sends these replies even when it refuses the new
size. Geometry replies alone do not establish a fault or prove causality.

Source matching requires a fresh snapshot, a unique XRes PID/class match to a
mapped, tiled X11 client, and a compositor window identity. The observer reads
the WM-maintained [`_NET_CLIENT_LIST`](https://specifications.freedesktop.org/wm/1.5/ar01s03.html),
not every root child: helper windows sharing the application's PID/class are
not additional managed windows. Two real managed windows with the same identity
remain ambiguous. A window on another workspace is eligible because Hyprland's
tiled configure/refocus path runs before its workspace visibility check. It rejects
ambiguous matches, missing fields, fullscreen and floating windows. XRes uses
the same server-side PID source as Hyprland; `_NET_WM_PID`, window titles and
process-name guesses are insufficient. Multiple managed windows from one process may
therefore remain undiagnosed. The private identity probe verified matching for
the fictional test client, not all Wine applications.

The runtime integration invalidates candidates on outside clicks, explicit focus
navigation, workspace changes, previews, menus, actions, reloads and closure.
Clicking Search or another part of the search panel does not relinquish keyboard
ownership, so it must not start an exclusion interval. Merely moving the pointer
to another monitor and back must not cancel a loss either. In particular, the
`focusedmon` event and pointer-follow focus reason are not proof of intentional
keyboard navigation. Neither event may erase the evidence of a lost search
focus; normal focus recovery and deliberate navigation exclusions still apply.
It observes the native window's activation state: `window.active` alone
misses the reproduced loss when Hyprland returns to its remembered application.
An explicit focus-dispatch reason can exclude an intentional switch, but the
reason labelled CLICK is also used by forced refocus. It is not evidence of a
physical click. Input exclusion needs independent lifecycle/input signals.

This is conservative evidence of a suspected interruption, not a guaranteed
cause detector. A matching timestamp pattern can occur coincidentally. Uncertain
cases must preserve normal input; do not retry focus acquisition in a loop.

## Notice and permission

The notice is passive: it does not take focus or open the details automatically.
Opening its details is the user's action. Notice: **Typing in search was interrupted — Review options**

Explanation:

> {app} may be interrupting your typing. Its window repeatedly asks for a different
> size. In affected Hyprland versions, this can send your keystrokes to the window
> under the pointer instead of WindowPeek

The options must describe the actual supported backend and its limitations.
For the native-window mode this includes lost touchpad scrolling
and potentially lost rapid wheel events outside the panel. Do not describe it
as affecting only touchpads, preserving every first wheel event, or fully safe.
The notice must also explain alternatives the user can try:

- Give the requesting window more room. This may help when requests are driven
  by insufficient space for its contents; it is an observation, not a guaranteed fix
- Use a normal floating window for the affected application; this avoids the
  reproduced tiled trigger. Do not promise the same for fullscreen or dragging
- If the application supports it, consider its documented native Wayland launch
  mode. For RSI, the [LUG Wine Wayland instructions](https://github.com/starcitizen-lug/knowledge-base/blob/main/wiki/Tips-and-Tricks.md#wine-wayland)
  describe runner selection and launch settings, including experimental options
  and known click-offset/graphics caveats. Bypassing X11 should avoid this specific
  X11 configure-request path, but compatibility with the user's launcher/game
  still needs testing; it is not a guaranteed repair
- Close the affected window when it is not needed

Keep instructions specific to a confidently identified application. Unknown
applications get generic floating/close suggestions, not a guessed launch
command. These are user-controlled alternatives; WindowPeek must not rewrite
launchers, switch Wine runners or move unrelated windows automatically. They
also do not constitute completion of the plugin-side fix.

Keep **Continue without changes** as the default. Enable **Enable temporary protection**
only after reviewing its limitations. The native-window mode uses the installed
Hyprland Lua API; no compositor replacement or configuration-file edit is needed.
Its scrolling limitations remain real, including on unaffected desktops. Missing X11/XRes or a valid managed-client list disables source attribution.
The generic interruption suggestion and manual setting do not depend on X11.
Missing Lua support disables the native protection backend and leaves normal input unchanged.

The policy grants consent only for an explicit `allow-for-window` decision
associated with the current incident. At that click the controller must recheck
the window identity, panel lifecycle and backend availability. Permission is
kept in memory for that exact compositor window identity and backend. Closing
WindowPeek releases protection while leaving that permission dormant; reopening
can reuse it only while the same source window exists. A restarted application,
reused address or changed backend must not inherit approval.

Closing the source window revokes permission and emits one notification:
**Temporary protection turned off — the affected window was closed**
The controller must finish releasing protection before delivering it. A failed
or stale inventory stops protection but is not proof of closure; do not emit a
misleading closure notification. A fresh, complete inventory can confirm it.
Manual stop also revokes permission. Dismissal and delayed events cannot grant
it, and shell/plugin restart must not restore a saved global preference.

## Runtime and limits

`FocusRecovery.qml` combines native activation, the pure `FocusIncident.js`
policy and the optional `tools/focus_observer.py` worker. The worker uses Python
and the installed X11/XCB/XRes libraries, selects only structure events, reports
bounded geometry/identity data, and exits on stdin EOF or a three-second lease
expiry. It reads no window titles or keyboard/pointer events and writes no logs.
`FocusWatch.js` observes intentional focus reasons with a one-second lease.

After confirmation, `NativeProtection.qml` maps the same panel content into its
own stable native viewport, shared with its live preview. `NativeProtection.js` applies a temporary focus
rule only to that uniquely identified WindowPeek window. Button and wheel
bindings release the hold outside it and pass the original input through.
The plugin’s own bar label is an exception: its physical button press is routed
to the same single/double-click handler, keeping protection active. Only that
label’s press is conditionally consumed to prevent duplicate Qt handling.
Moving across monitors or toggling compact/expanded mode must not pause protection.
The label bounds are refreshed with the native window’s lease. Changed callback
versions disable old handles before replacing them after a shell restart. Both the rule and the bindings
expire after one second without renewal; no configuration files are written.
Expiry reports a backend failure to the panel, so an expired hold cannot remain
labelled as active. It never starts an automatic focus-recovery loop.
Outside scrolling intentionally pauses temporary protection so the application
beneath the pointer can receive input. Pointer movement and typing alone must
not pause it. Support IPC reports `protectionPaused`, `protectionLastYieldReason`
and `protectionLastYieldAt`. The last transition cause (`outside-wheel` or
`outside-button`) survives dismissal in memory; it contains no input text or
window identity. Subsequent events while already paused do not overwrite it.
Search, settings, previews and move menus share the same controller. Hold is
paused during child menus and actual pointer interaction with a preview. A passive
thumbnail alone does not release Temporary Protection. A visible Turn off action
revokes consent.

Window inventory refreshes preserve an already-active hold while a request is
pending, up to the reader's two-second deadline. Old data cannot start or restart
protection. Failed reads suspend it; a fresh observation of source closure or a
changed identity revokes permission as before.

The protected native viewport keeps its size during filtering and compact/expanded
animation. Only the visible card and preview change geometry; transparent space
is excluded from pointer input. While protection yields, hit-testing also excludes
space outside those items. Their bounds are updated for the outside-scroll policy.
Mapping applies the latest layout immediately; the lease reconciles delayed
configure replies. These operations affect only the uniquely titled, PID-checked
WindowPeek window.

Closing releases the focus hold immediately but keeps the fading card in its
native window until opacity reaches zero. The rule remains alive until that
window unmaps. The card is then returned to its normal layer while invisible;
it must not switch surfaces during fade-out. Window activation after dismissal
waits for both the layer and native window to unmap.

The regular first and second wheel packets were preserved in private tests.
Touchpad FINGER events and wheel events inside Hyprland's binding throttle can
still be lost outside the protected panel. The confirmation explains this before
approval. Do not call this a complete compositor repair or silently enable it.
Attribution is conservative: ambiguous multi-window identities produce an
unidentified interruption notice instead of naming a source. Native tests do not
establish a real-world false-positive rate.

## Local issue history and explicit ignores

`FocusIssues.qml` stores bounded, normalized history in `focus-issues.json` beside
preferences. Only a validated suspected-source incident records an app. Entries
use the X11 initial class (current class fallback), a display name, first/last
observation times and count. PID, window address, titles and search text are not
persisted. `FocusIssues.js` keeps this policy independent of focus grants.

Session ignore is keyed to `HYPRLAND_INSTANCE_SIGNATURE`, so it survives a bar
restart but expires after logout/compositor restart. If that identifier is
unavailable, a process-local token conservatively expires on bar restart.
App and global ignores persist. Unrelated/unknown incidents are not muted by an
app ignore. The observer can still record identified incidents while globally
muted. Controls in Troubleshooting restore each scope independently. A global
or session ignore overrides an individually enabled app's warnings.

Atomic writes must succeed before the UI confirms a choice. Invalid files are
not overwritten. History is capped at 256 apps; only a non-ignored oldest entry
can be evicted. If all entries are ignored, new apps are not added. Stored
identities are a grouping convenience, not a security identity or permission
for an automatic mitigation. Restarted apps never inherit a protection grant.

## Explanation and settings layout

The review dialog shows the suspected app and suggests giving its window more
room or making it floating. Users can choose temporary protection, protection
for every search, warning preferences or continuing without changes directly.
Each protection choice states its scrolling limitations before activation.
**Troubleshooting · details and settings** is an optional next step. Opening it dismisses the thumbnail and
hides the underlying list controls; it uses the enclosing panel's wallpaper,
glass or solid background in both compact and expanded views.

Troubleshooting starts with the symptom and a brief possible cause, followed by
simple alternatives. Persistent protection and its input restrictions come next.
Warning preferences and the suspected-app history are separate sections; app
switches explicitly say that they ignore warnings. Viewing this explanation does
not enable protection or mute warnings.

Identified, unidentified and repeated interruptions all open this brief review
first. When the source is unidentified, the short notice offers temporary
protection until manual switch-off or bar restart. This in-memory consent survives
panel close/reopen and unrelated window closures, without changing the permanent
setting or inventing a source. Identified-source grants still end when that exact
window closes. Detailed settings open only when
requested. Returning follows the entry route: directly opened help returns to
the list, help opened from review returns to review, and help opened from Controls
returns to that section with its scroll position preserved.

Approval waits for fresh post-click compositor and XRes samples. These readers
update independently; an older sample is a reason to wait, not immediate proof
that the window changed. The existing 500 ms freshness and identity checks still
apply. The button shows “Checking window…” while pending, with a 2.5-second
deadline. Cancellation, closure, changed identity or an unavailable source never
grants protection from a late result.
