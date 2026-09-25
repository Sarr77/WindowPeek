# Changelog

## 0.7.2

- Smooth expansion and collapse with or without live preview and typing
  protection. Share one render surface, keep the protected viewport stable and
  synchronize resizing with rendered frames, including rapid reversals.
- Move wallpaper text-contrast calculations off the UI thread and reuse sampled
  crops, color decisions and prepared shortcuts to reduce pauses.
- Detect interrupted search without relying on application names. Offer temporary
  typing protection, practical alternatives and a short explanation before consent.
  When the source is unknown, temporary protection lasts until turned off or the
  bar restarts; otherwise it ends when that window closes.
- Add Controls → Troubleshooting with optional Keep search focus, warning ignores
  until logout, per app or globally, and a local history of suspected applications.
  Permanent protection asks for confirmation and explains its scrolling restriction.
- Restore real keyboard focus on a panel click after an interruption. Hide the
  caret when typing belongs elsewhere, keep protection with passive previews,
  and preserve the current view during closing and protection changes.
  Release the ordinary search hold after keyboard loss so other windows regain
  normal mouse-focus behavior immediately.
- Add Automatic, On and Off text readability controls for wallpaper and transparent
  panels, including preview captions, input placeholders and the active bar label.
  Keep text readable on the first opening while wallpaper analysis is pending.
- Type in the compact panel to expand directly into Search. Keep search ready
  outside the panel, even with an empty query. Ordinary compact browsing follows
  mouse focus and releases its navigation keys when another window takes input;
  returning by hover needs no click. Preserve scroll positions on pointer return.
  Warn about focus loss only once Search is expanded, not while browsing compact mode.
- Add optional double-click expansion and a separate compact pinning switch.
  Support saved shortcuts, list navigation and Move from compact search.
- Show contextual hints only for the hovered element, below the panel without
  overlap. Include bar-label gestures and instructions for the current interaction mode.
- Move logo settings into Personalization → Pictures and Gifs. Choose separate
  static images, GIFs or pixel animations, with independent Loop animation switches,
  fractional Delay loop values, cooldowns, timing resets and an optional shared cooldown.
  Fix local image selection and preserve Settings animation across submenu visits.
- Make Back and right-click follow the user's navigation path, including nested
  Settings sections. Blur settings input fields after editing and pass outside
  wheel input through when protection does not deliberately block it.
- Add Follow bar style for wallpaper panels, independent hover and preview delays,
  and mouse-wheel speed from 50% to 300% (default 102%).
- Correct preview pointer bounds on offset monitors and guard expired Hyprland
  keybinding handles. Save preferences asynchronously with ordered writes.

## 0.7.1

- Stop automatic hover hints after 100 displays; manually enabled hints stay on
  until switched off.
- Use consistent spacing around shortcut separators in hints and help.

## 0.7.0

- Use Omarchy's standard plugin commands for installation and removal; omit
  the separate installer from the public source and release archive.

- Start with Wallpaper and subtle grain enabled, with blur off. Preserve
  existing saved choices and assess wallpaper contrast per theme.

- Preserve a theme's RGB and native Solid opacity when its popup color includes
  an alpha channel, rather than falling back to white. Keep the per-theme
  Wallpaper slider in Personalization as the place to adjust its transparency.

- Remember Wallpaper transparency per theme, with a reset to each theme's initial
  level. Wait for a theme's actual text colors before measuring contrast.
  On first use, reduce transparency only for severely unreadable wallpaper
  crops; preserve acceptable backgrounds and later manual adjustments.

- Outline the selected color element in the appearance preview, keeping the
  selection visible when using either the preview or the element dropdown.

- Keep an open preview visible when Ctrl+clicking a list row to move a window,
  avoiding a flash and a capture restart while choosing the destination.

- Resolve held mouse modifiers from Hyprland even after hover gains keyboard
  focus, so Ctrl+click opens Move instead of focusing the window. Match the
  destination menu to the selected panel background, including Wallpaper.

- Add a keyboard and mouse shortcut editor in Controls, with protected recording,
  a mouse-based key picker, conflict checks, per-action resets and Apply/Cancel.
  Both views, previews and help use the saved bindings across monitors.

- Open with Super + Alt + P and choose a visible window or group tab with
  1–9 / 0 for five seconds, including the numeric keypad without Ctrl.
  Typing starts search immediately. Register the opening shortcut automatically
  when available, preserving existing user bindings.
- Navigate the window list with Page Up, Page Down, Home and End.
- Match Wallpaper dropdown backgrounds to the desktop image and its effects,
  with a readable tint and no settings text showing through.

- Check for updates about a minute after startup when there has been no check
  that day, then every six hours. Preserve the deadline across restarts.
- Fit dropdowns to their rows, borders and padding; prevent tiny wheel movement
  in lists that already fit and scrolling through to the editor underneath.
- Clarify the color reset label and soften dropdown backgrounds in Wallpaper
  and Transparency with a subtle theme tint.
- Select color elements by clicking the live appearance preview.
- Place the color preview above its controls and keep it still when selecting
  elements. Outline the Colors and Interface size entries in Personalization.
- Accept Ctrl + numeric keypad digits in hover and search, including when
  Num Lock is off. Use the same visible-row numbering as the top digit row.
- Catch fast Ctrl+digit shortcuts before hover takes keyboard focus, preventing
  them from reaching the application underneath.

- Add Wallpaper and Transparency backgrounds for panels and window previews.
  Wallpaper follows the desktop image without showing applications underneath.
- Adjust transparency with a slider, separate saved values and reset. Add
  optional wallpaper blur and subtle grain while keeping your theme’s colors.
- Wait for wallpaper loading before fading in the panel, avoiding a dark flash.

- Customize panel, row, menu and grain colors; adjust brightness and individual
  field transparency, with theme-specific appearance presets and resets.
- Show Wallpaper and Transparency in the appearance editor’s live preview.
- Toggle hover and search with a middle click on unused panel space.
- Fit preview frames to the window’s proportions and offer a switch for the
  dark inset behind the captured image. Keep the frame size steady until the
  preview is closed; reopening fits the window’s current proportions.
- Show the installed version beside the author in the expanded footer.
- Keep the translucent Settings wordmark above the wallpaper effects.
- Expand the color editor to fit its contents within the monitor's available height.

## 0.1.0

First release.

- Find windows across monitors, workspaces and Hyprland groups.
- Browse on hover, expand to search, and preview a window before switching.
- Choose where to move a window, or bring it to your current workspace.
- Switch to windows and group tabs in list order with Ctrl+1–9/0.
- Hold Ctrl in hover or search to see shortcuts for visible rows, with optional
  right-aligned numbers. Ctrl can already be held when opening the list.
- Hold Shift to hide window previews while browsing.
- Customize colors, size, labels, delays and animations, with 30 languages.
- Keep preferences across restarts and installs; check verified releases daily.
