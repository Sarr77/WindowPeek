# Troubleshooting

Open **Settings → Controls → Troubleshooting**, or choose **Review options**
when WindowPeek reports interrupted typing. Review options shows a short choice
of solutions first; the full settings are optional.

## Text goes to another window

Search can lose keyboard input when the pointer moves over another application.
Some X11 apps, including apps running through Wine, repeatedly request a different
window size. In affected Hyprland versions, those requests can redirect input.
Other focus problems can have different causes. A suspected app is a clue, not
proof; WindowPeek does not guess a name when the source is unknown.

Try giving the suspected window more room, or make it floating. This may help
when the app is trying to fit its contents into a small tiled area. You can also
close it when unused. If it supports native Wayland, its documented Wayland mode
may be worth trying.

The short notice lets you choose:

| Choice | What it does |
| --- | --- |
| Continue without changes | Returns to Search without enabling protection |
| Enable temporary protection | Keeps typing in WindowPeek until the identified window closes; if the source is unknown, until you turn it off or restart the bar. Scrolling outside pauses protection; click the panel to resume. Touchpad scrolling or fast wheel input outside may be lost |
| Keep focus every time | Asks for confirmation, then protects every opened search, including pinned compact search. Blocks mouse-wheel and touchpad scrolling outside the panel. Click outside or press Esc to close it. Turn this option off in Troubleshooting |
| Ignore warnings… | Hides warnings without enabling protection or fixing the interruption |

For an identified and checked source, temporary protection turns off with a
notification when that window closes. If the source is unknown, the notice instead
offers protection until you turn it off or restart the bar. It remains enabled
when you close and reopen the panel; no app name is guessed. Opening an explanation
never enables either kind of protection. Keep search focus releases its hold
while you use Settings.

Use **Keep search focus** only if applications frequently interrupt typing.
The confirmation explains its scrolling restriction and where to turn it off:
**Settings → Controls → Troubleshooting**. Once enabled, it does not add a routine
status banner. Temporary protection keeps its app name, options and Turn off button.
Turning it off leaves Options available, including in compact search. For an
identified source, this lasts while its window remains open; for an unknown
source, until the bar restarts. Re-enabling it requires another explicit approval;
Turn off does not mean Ignore warnings.

A temporary backend failure does not erase your saved choice or approved window.
WindowPeek tries restoring protection twice. If that fails, it shows an interruption
with Retry; reopening the panel also retries. The setting stays enabled, but an
interruption message means input is not currently protected.

## Manage warnings and suspected apps

Ignore warnings until logout, for one app, or for all focus interruptions.
Session ignore survives a bar restart; app and global choices persist until you
restore warnings in Troubleshooting.

The local app history shows suspected apps, when they were detected and how many
interruptions were recorded. Each app has its own ignore switch. Session or
global ignore still takes precedence over an app's switch.

History stays on your device. Window titles and search text are not stored.
App matching uses its application class, so apps sharing a class share the choice.

## Panel animation stutters

Update to 0.7.2 or later. The reproduced lower-refresh-rate stutter is fixed:
the panel and live preview share a render surface, protection keeps a stable
viewport, and expansion follows the presenting window's frames. You do not need
to disable preview or change your monitor's refresh rate for this fix.

If it still happens, note your display modes, graphics driver, protection mode
and whether preview is visible. See [Known Issues](KNOWN_ISSUES.md#choppy-resizing-with-a-visible-window-preview)
for tested conditions and useful reporting details. This fix does not guarantee
one distinct animation update per refresh on a 240 Hz display.
