# Changelog

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
