# WindowPeek

Author: Sarr. Target: Omarchy with its native Quickshell shell and Hyprland.
Plugin ID: `sarr.windowpeek`. Repository: `Sarr77/WindowPeek`.

## Purpose

Help a person find an application window and switch to it without remembering
which workspace, monitor or Hyprland group contains it.

Example: search for part of a project's name, select a VS Code window hidden in
a group on workspace 4, and arrive at that window with the correct tab selected.

## Scope

- Search by application name and window title, with results updating as you type.
- Group the list by workspace and show the associated monitor.
- Show individual Hyprland group members, including inactive or hidden tabs.
- Clicking a row or pressing Enter focuses that exact window. The appropriate
  workspace and group member become visible as part of navigation.
- Focusing preserves the window's monitor, including hidden or visible special
  workspaces. Ctrl+Shift+click brings only the selected window to the active ordinary
  workspace of the monitor containing WindowPeek, then focuses it. Explain the
  gesture in hover help. If already there, focus without detaching its group.
- Ctrl+click opens a small destination menu at the click position from either
  list or its preview. Keep the list in its current mode and retain hover while
  the menu is open. A menu opened on the preview retains that preview and its
  capture until the menu closes or a move starts. Search or scroll to a workspace;
  selecting it moves the window. Pin Move to Scratchpad below the scrollable list,
  without duplicating it among the rows; disable it when already there.
  Escape, right-click or an outside click cancels. Keep the menu within the invoking screen.
  The separate Move control keeps the full form with explicit Move now confirmation.
  Show the source workspace in both; include its monitor in the full form. Keep a Move to Scratchpad
  action in the main form above the dropdown, reachable without scrolling or choosing
  a destination first. It moves only that window, without switching workspaces,
  and is disabled when the window is already there. Fit the move form to its
  content, including the dropdown while open.
- Support mouse and keyboard navigation, plus a configurable shortcut to open
  the panel. Plain clicks on unused panel space expand the hover view or return
  the window list to hover. Returning clears the search filter. Controls retain
  their own actions; settings and move forms do not collapse on background clicks.
- Allow disabling the hover panel. In click-only mode, the bar and shortcut open
  the full panel, and background clicks cannot collapse it.
- Include special workspaces, including the scratchpad, with a setting to hide them.
- Keep the familiar ScratchPeek appearance: compact panels, application icons,
  configurable colors, scaling, translations and durable settings.

The tab scope is Hyprland window groups. Browser tabs and editor documents would
require separate integrations and are outside this first product scope.

## Panel behavior

The panel has a search field at the top, followed by workspace sections
and window rows. A row shows an application icon, the window title and a
secondary application name. Both lists use the same workspace headers: a labeled workspace name on
the left, with its monitor aligned to the right. Only hidden workspaces carry
a “Hidden” marker; workspaces shown on any monitor have no status label. The layout
mirrors for Arabic. Destination choices use the same workspace labels.
Mark the active window and grouped tabs clearly.

- Clicking the bar expands the existing rounded hover panel over 200 ms by default, keeping
  its rows, order and scroll position. Search, Move, Settings and the footer
  become available in the same surface. Opening directly starts expanded.
- Opening the expanded panel focuses search. Arrow keys select a result; Enter activates
  it; Escape closes the panel. Closing without an action restores prior focus.
- A hover changes only the hovered control's appearance. It does not focus an
  application or move a window. Highlights clear when leaving that control.
- Resting the pointer on a window row opens a small content preview beside the
  list after 400 ms by default. It preserves the window's proportions, follows the theme
  and scale. Its top stays at or below the list panel's top edge. The same
  preview is available in the bar overview. Keep the list and
  preview open while the pointer moves between them, including across their gap.
  Stopping in that gap keeps both open and preserves the row's hover highlight.
  Clicking the preview focuses that window; Ctrl+Shift+click brings it here, just as
  on the row. Leaving both surfaces closes the preview after a short delay.
  The preview title wraps to two lines, with an ellipsis for longer text.
  Click instructions appear as row hover hints in search when hints are enabled;
  the preview card contains no instruction footer.
- Holding Ctrl temporarily suppresses window-content previews in both lists.
  It hides an existing preview and releases capture, except while the pointer
  is on that preview card or its move menu is open. Leaving the card while holding Ctrl hides it otherwise; the
  transparent handoff gap is not part of this exception. Releasing Ctrl starts
  the normal hover delay again for the row under the pointer. List interaction,
  titles, icons, scrolling and existing Ctrl+Shift+click actions remain available.
- Window previews are enabled by default, with a persistent switch in Settings
  shared by both lists and all monitors. Turning them off closes any open preview,
  including one under the pointer, and stops capture and Ctrl-state observation.
  Turning them back on restores the normal hover delay and Ctrl behavior.
  Row hints and actions keep their own behavior.
- Separate bar-hover and window-preview delays accept 0–2000 ms, both defaulting
  to 400 ms. Zero opens without a dwell timer. Popup animations are on by default;
  turning them off removes fades and the click-to-expand transition. Rounded
  borders, row feedback, Ctrl privacy and pointer handoff remain available.
  Save these choices through the shared durable preferences path.
- Window rows and Move have subtle resting frames, accent hover frames and a
  stronger pressed fill, with brief color transitions and no layout movement.
  The active-window stripe stays distinct from hover and keyboard selection.
- Clicking a window and clicking Move are distinct hit targets with clear labels.
- Keep selection attached to an address as data changes. A closed window must
  not cause the next row to receive the original action by accident.
- Empty search results and compositor data that is not ready are distinct states.
- Use equal visual margins and a separate right-side gutter for the scrollbar.
- Size the opening list to a complete window row near its preferred height,
  including workspace headings and spacing. On smaller screens, stop at the
  previous complete row. Scrolling does not resize the panel or snap the list.
- Compact density reduces row heights and section spacing in both lists while
  preserving text size. Settings and Back need no redundant hover hints.
- Right-click goes back in settings, editors, move forms and nested pickers.
  Close only the current picker; leaving an editor discards its unsaved draft.
  Right-click in an update-disable confirmation cancels it. Right-click anywhere
  in the main list closes the panel and its preview, in hover and expanded mode.
- Enable springy scroll edges by default in both lists, with a persistent
  Settings switch for firm boundaries. Preserve existing saved choices.
- Preserve plain text rendering for application-supplied names and titles.

The default bar label is **WindowPeek · count**. The agreed local shortcut is
**Super + Alt + P**. Special workspaces start included and can be hidden in
Settings. The installer leaves shortcut configuration to the user.

## Bar preview

Hovering the bar label opens a compact overview after a short delay. Show app
icons and titles, grouped by workspace with monitor names. Put the active
window and its workspace first. Include every window and workspace allowed by
the current preferences. Keep the panel height bounded and scroll the list
with the mouse wheel or scrollbar. Clicking a row closes the hover and switches
to that exact window or group tab; clicking the bar expands it into search.
Keep the opening active window first for that session, without rearranging rows
when focus changes.
Ctrl+Shift+click has the same bring-and-focus behavior as the search panel.

The preview follows the same special-workspace preference as the count and
search. It fits the screen at the chosen scale and stays readable when the
pointer moves onto it. The transparent gap between the bar and the adjoining
panel edge also retains hover, including while the pointer is stationary there.
Returning to the WindowPeek label retains the same panel immediately, without
fading or restarting the opening delay. It does not take keyboard focus until expanded. Opening
another bar popup dismisses it. Hint limits affect only the help footer;
window information remains available when hints are off. Refreshing inventory
preserves scroll position, and dragging the scrollbar keeps the popup open.

## Settings and the ScratchPeek design language

Keep WindowPeek's preferences independent from ScratchPeek's preferences.
The intended state directory is `$XDG_STATE_HOME/windowpeek`, falling back to
`~/.local/state/windowpeek`. Restore choices after restart and reinstall.

Keep language first, then four expandable categories: Panel and previews, Window
list, Personalization and Controls. Controls is a translated guide to mouse and
keyboard actions, including the optional system shortcut. Use full-width outlined headers with clear expand/collapse
indicators, keyboard operation and wrapped titles. Start collapsed on entering
Settings; preserve expanded categories while visiting an editor. Collapsing a
category closes its pickers and removes hidden controls from keyboard navigation.
Keep a larger fixed panel height, bounded by the monitor. Expanding a category
must not scroll its header away from the pointer. Enabled switches use the resolved
Colors accent; inactive switches stay muted and also differ by knob position.
Fit the panel to its content, with bounded scrolling when expanded. Use readable
labels, secondary text and generous control targets. Boolean choices use labeled switches; delay
controls sit beneath their respective switch and stay visible but disabled when
unavailable. Editor entries show saved-value summaries and a directional chevron.
List density saves immediately in Window list. Colors edits only color settings.
Returning from an editor restores the entry's focus and scroll position. Simple
controls reflect durable saved state, including when a write fails.
Show defaults beside settings. Offer a per-value Reset for delays, scaling,
colors and custom text. Delay resets save immediately. Editor resets remain
undoable with Cancel or Back until Apply; keep unrelated choices and presets.
Clicking an open dropdown's trigger closes it without reopening on release.

Carry over these established design decisions where they fit WindowPeek:

- Panel and tooltip scaling, with bar text scaling controlled separately.
- Native theme colors; an adapted `#D898F5` accent for Tokyo Night; custom colors
  from a color picker and HEX field, with live preview.
- A compact, collapsed preset section below the color picker. Apply saves and
  Cancel restores; the restore control uses the last saved color.
  Preset buttons show their color swatch and full HEX, independent of the selected color.
- Thirty languages, automatic detection on first launch and a manual selector.
  The exact source list is recorded in the reference document. Translate new
  WindowPeek wording instead of copying scratchpad-specific descriptions.
- A grouped text editor for the bar, headings, workspace and window labels,
  actions and hints. Preview changes across monitors, save on Apply and discard
  on Cancel, Back or dismissal. Blank fields follow the current language;
  custom text remains literal when changing languages. Offer translated defaults
  without deleting saved custom text, and a reset that remains undoable until
  Apply. Explain and validate each field's available variables. Technical
  settings, error messages and author attribution keep their application text.
- A small help control at the left of the footer, with its own explanation
  always available. Automatic hints use the first 200 displayed hovers, shared
  across monitors and persisted; manually enabled hints stay on until disabled.
- Help descriptions have no final full stop. Preserve meaningful action ellipses
  and sentence separators. Use natural, explicit text instead of unexplained icons.
- Plain `by Sarr` at the other end of the footer, without a link initially.
- A subtle daily-update control beside help, enabled by default. Disabling
  requires confirmation. Install only immutable WindowPeek releases whose exact
  commits are verified in the official catalog; preserve settings and local work.

## Delivery quality

Use the native Omarchy UI components with a small, understandable application
structure. Keep behavior verifiable and changes small enough to review. Avoid
frameworks, services or abstractions that do not solve a current requirement.

Desktop window operations need checks against real compositor behavior. A passed
pure-model test alone does not prove focus or group navigation works. Validate
the full interaction on multiple workspaces and monitors before calling it ready.
