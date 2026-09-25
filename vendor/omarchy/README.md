# Omarchy components

The controls in this directory are adapted from Omarchy 4.0.4; see
[the source reference](../../docs/SCRATCHPEEK_REFERENCE.md).

`WidgetButton.qml` retains the bar control’s layout and pointer handling, with
an `animateTextColor` switch so WindowPeek can change ink and shadow together.

`WindowPanel.qml` exposes its layer scene and separate preview input/blur regions
so the live preview can move with the panel in one surface. The transparent
handoff bridge accepts pointer input without blurring the background.

`PopupMotion.qml` is a local motion helper. Expansion uses the presenting window's
frame events and a monotonic clock; opacity and detached hosts retain a standalone
animation. Both paths stop synchronously when animations are disabled.

`logo.svg` is the original Omarchy wordmark from commit
[`e8d095c7874ec847f1317a70a74cd0c41a3df814`](https://github.com/omacom/omarchy/blob/e8d095c7874ec847f1317a70a74cd0c41a3df814/logo.svg).
`OmarchyLogo.qml` renders the same paths with the chosen accent color, without
an image filter or a network request. Settings uses it as a background decoration.

Copyright David Heinemeier Hansson. The [MIT license](LICENSE) is retained.
