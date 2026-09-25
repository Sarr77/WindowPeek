# ScratchPeek reference

WindowPeek's baseline is ScratchPeek **0.11.0**, by Sarr, under the MIT license.

- Repository: https://github.com/Sarr77/ScratchPeek
- Exact commit: `342efb5225cb0f56349f5bf1f96aa38f5298ab39`
- [Pinned source tree](https://github.com/Sarr77/ScratchPeek/tree/342efb5225cb0f56349f5bf1f96aa38f5298ab39)

Automatic updates and durable settings use the later **0.11.1** reference,
commit `06bf2b930303d9cf65224f61a8099258065f6b76`:
[pinned source](https://github.com/Sarr77/ScratchPeek/tree/06bf2b930303d9cf65224f61a8099258065f6b76).
This supersedes the 0.11.0 updater. `update.py`, `Updates.qml`, `Preferences.qml`,
settings synchronization and their update/preferences/lifecycle tests are
adapted from that version to WindowPeek's runtime, identifiers and paths.

## Reference map

| ScratchPeek source | Use in the WindowPeek design |
| --- | --- |
| `ScratchState.qml` | Shared Hyprland inventory, monitor/workspace data and event-driven refresh |
| `Model.js` | Window identity, group metadata, validated focus command and settings revision handling |
| `Widget.qml` | Native bar integration and restoring saved preferences |
| `Details.qml` | Compact window rows, explicit focus/move hit targets and keyboard behavior |
| `Transfers.js`, `WindowTransfer.qml` | Safe movement of individual group members and completion checks; generalize endpoint rules |
| `PanelSelection.qml` | Separate pointer hover from keyboard selection |
| `ScrollHandle.qml`, `PopupPlacement.js` | Scrollbar placement and keeping popups within scaled window bounds |
| `Preferences.qml` | Atomic durable settings independent of bar layout |
| `Appearance.js`, `AppearanceEditor.qml`, `ScalingEditor.qml` | Colors, collapsed presets, saved-color restoration and scaling |
| `LabelsEditor.qml`, label helpers in `Model.js` | Plain-text templates, shared live preview, Apply/Cancel and translated fallbacks; adapted to WindowPeek's field groups |
| `HintsToggle.qml`, `PanelHint.qml` | Shared hint budget and always-available help control; WindowPeek uses 100 automatic displays |
| `UpdateSwitch.qml`, `UpdateConfirmation.qml`, `Updates.qml`, `update.py` | Subtle update controls and daily release handling; replace every product-specific identifier |
| `I18n.js` | Locale selection and all 30 language catalogs |
| `tests/`, `tools/`, `docs/TESTING.md` | Focus/group cases, live checks, isolated profiles and known validation limits |

Keep the reference pinned so future ScratchPeek changes do not silently alter
the implementation baseline. Reused code should be selected and adapted by
responsibility, preserving license notices. WindowPeek has no runtime dependency
on ScratchPeek.

## Languages

English, Polish, German, French, Spanish, Brazilian Portuguese, European
Portuguese, Italian, Dutch, Swedish, Danish, Norwegian Bokmål, Finnish, Czech,
Slovak, Ukrainian, Russian, Turkish, Romanian, Hungarian, Greek, Arabic, Hindi,
Indonesian, Vietnamese, Thai, Japanese, Korean, Simplified Chinese and Traditional
Chinese.

Preserve right-to-left handling and test new labels at larger scales. Do not
reuse scratchpad state wording for ordinary workspace/window navigation.

## Known limit to carry forward

ScratchPeek 0.11.0 records diagnostics for an intermittent scratchpad visibility
warning whose cause was not reproduced. Its visibility controller is not proof
of a general solution for navigating ordinary workspaces. WindowPeek's focus
behavior needs its own fresh-state and completion checks.

## Code used in WindowPeek

The appearance editors and helpers, hints, scrolling and popup placement were
selected from 0.11.0; updates and preference persistence now use the 0.11.1
reference above. `I18n.js` retains the locale machinery and relevant catalog entries,
with WindowPeek messages added in all 30 languages. The inventory reader, model,
action controller and main panel are specific to WindowPeek.
The text editor follows ScratchPeek's draft and preview behavior, with a separate
field catalog and per-field variable validation for WindowPeek.

`vendor/omarchy/Dropdown.qml` and `SearchableDropdown.qml` come from Omarchy 4.0.4
through the ScratchPeek adaptations for scaled popup placement. `vendor/omarchy/WindowPanel.qml` adapts the same Omarchy version’s
`Ui/KeyboardPanel.qml` for the shared hover/search surface. Their original
MIT notice, copyright David Heinemeier Hansson, is retained in
`vendor/omarchy/LICENSE`. The remaining selected ScratchPeek code is by Sarr,
covered by the root MIT license.

The native modifier-key test uses the virtual-keyboard protocol definition in
`tests/protocols/virtual-keyboard-unstable-v1.xml`. Its original MIT notice
is retained in that file; it is a test dependency, not part of the runtime.

The pointer-frame helper uses `tests/protocols/wlr-virtual-pointer-unstable-v1.xml`
from [wlr-protocols](https://github.com/swaywm/wlr-protocols/blob/b010a03648b88d143236de193bddbfea0c08bc84/unstable/wlr-virtual-pointer-unstable-v1.xml).
Its MIT notice, copyright Josef Gajdusek, is retained in the protocol file.
Like the virtual keyboard, this is used only by coordinated desktop tests.

The decorative Omarchy wordmark in Settings uses the original paths from
[logo.svg](https://github.com/omacom/omarchy/blob/e8d095c7874ec847f1317a70a74cd0c41a3df814/logo.svg).
Its source and QML rendering are under `vendor/omarchy`, with the same MIT notice.
