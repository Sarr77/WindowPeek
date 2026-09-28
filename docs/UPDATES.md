# Updates

## Checking and installing

Open **Settings → Controls → Updates**. The page shows the current status and
last check time. **Check now** looks for newer public code in `Sarr77/WindowPeek`;
when an update is found, the same button becomes **Update…**. **View changes**
opens the checked comparison on GitHub; otherwise **Version history** opens the
public history. A newer commit can be available without a version-number change.
An unreachable catalog is shown as unknown, never as verified. Checking uses the
status area without flashing the button label or moving controls.

**Update…** opens `omarchy plugin update sarr.windowpeek` in a terminal.
Omarchy fetches the current default branch, shows the changes and asks before
applying them. This can install code not yet verified by the catalog. Review the
terminal's diff: it may be newer than the earlier check. Declining keeps the
installed code; accepting an update restarts the bar after the commit changes.
There is no `--yes`, administrator access or downloaded installer. GitHub draft
releases are not a public source.

Manual updates require a clean standard Git installation from the original
repository. Development links, forks, local changes and ahead copies are protected.
Their page keeps **Check now** and **Version history** as matching buttons, with a
short explanation that installation is protected. Development copies are managed with Git. The worker checks
eligibility again in the terminal and shares the automatic updater's process lock.
It uses the native command's directory, `~/.config/omarchy/plugins`.

## Update notifications

The compact **Auto updates** footer switch and its label toggle update notifications together.
Enabling is immediate. Disabling opens a confirmation with **Open Updates** and
a smaller **Turn off** action. Opening Updates changes no preference; closing
the popup or pressing Escape also keeps notifications enabled. Back restores the
previous view, including any unsaved editor draft.
Clicking outside a confirmation closes only the popup; the underlying panel stays open.
The same notification setting is available on the Updates page and is enabled by default. It checks
metadata every six hours while panels are idle; it does not install anything.
An available update appears beside Settings in the expanded window list and opens
Updates. Back restores the search and list position. Turning notifications off
stops scheduled metadata checks and hides that notice; manual checking still works.

Opening Updates uses cached results and starts no network request. **Check now**
works with both switches off. Checks run outside the UI process; metadata results
live in `manual-updates.json` and do not fetch Git objects or change code.

## Automatic updates

**Automatic updates** is a separate, default-on option only on the Updates page:

> Automatically install releases verified by Omarchy. Verification may take time — newer updates remain available with your confirmation.

It installs only the verified stable releases described below. Unverified code
always requires manual confirmation. Existing saved choices are preserved;
changing notifications does not change automatic installation, or vice versa.
Turn both options off to stop scheduled update requests.

Turning automatic installation off requires confirmation. Cancel, Escape and the
default Enter preserve it. Mouse dismissal leaves no focus highlight; keyboard
dismissal returns focus to the setting. A failed save keeps the saved choice.
Unreadable settings are never silently overwritten.

## Schedule and storage

Automatic installation and notification checks keep separate timestamps.
Notification checks become due six hours after their previous attempt and run
when the minute timer finds all panels idle; they have no once-per-day shortcut.
The startup/day rule below applies to automatic installation checks.

About a minute after startup, WindowPeek checks if no attempt has been recorded
on the current local calendar day. Later checks are due six hours after the
previous attempt. Restarts on the same day keep that deadline; they do not add
startup requests or restart the six-hour wait. An overdue check runs on the next
available timer tick. Crossing midnight without a restart keeps the regular cadence.
An open panel, hover popup or window operation postpones
starting a check. This does not cancel a check already in progress.

Preferences, the schedule and the process lock live separately from code in
`$XDG_STATE_HOME/windowpeek/` (default `~/.local/state/windowpeek/`):
`preferences.json`, `updates.json` and `updates.lock`. All monitors share them;
restarting the shell preserves the deadline. No worker starts without valid,
saved preferences. There is no background service between checks.

## Automatic release approval

Automatic installation accepts only a newer stable `vX.Y.Z` release from `Sarr77/WindowPeek`, marked immutable
by GitHub, can be installed. Its tag must resolve to the exact commit approved
by the official [Omarchy catalog](https://plugins.omarchy.org/catalog.json).
Schema 2 must contain exactly one entry with:

| Field | Required value |
| --- | --- |
| `id` | `sarr.windowpeek` |
| `repo` | `https://github.com/Sarr77/WindowPeek` |
| `sourceType` | `community` |
| `repositoryLayout`, `manifestPath` | `root-plugin`, `manifest.json` |
| `installAvailable` | `true` |
| `verificationSnapshotStatus` | `verified` |
| `listingValidatedCommit`, `verificationCommit` | The same full 40-character lowercase SHA |

Built-in and placeholder entries are rejected. Missing approval, duplicates,
unknown schemas, mutable releases and service errors stop installation.
There is no fallback to `main`, another tag or cached approval. A CI result,
issue label or bot comment is not catalog approval. See the marketplace's
[verification contract](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md).

## Automatic installation checks

The installed copy must be a clean Git checkout from the original repository.
Development symlinks, forks, non-Git copies, untracked or ignored files and
`assume-unchanged` / `skip-worktree` flags prevent replacement. Custom local
filters, config includes, repository extensions and alternate object stores
are also skipped. The current commit must be an ancestor of the release.

The worker fetches only the release tag into a fresh directory outside
`plugins/`. It checks Git objects, ancestry, file types, the manifest and the
Omarchy validator. Symlinks and submodules are rejected. Raw file bytes and
executable modes are compared with Git blobs in both the installed and staged
trees, including changes hidden by checkout conversions.

Immediately before replacement it rechecks the release, catalog approval, tag,
saved opt-in and installed tree. Linux `renameat2(RENAME_EXCHANGE)` swaps the
complete directories; there is no non-atomic fallback. Download, verification
or exchange failure leaves the previous installation in place. After success,
the old tree is removed and Omarchy's shell is restarted to load fresh QML.
Settings are retained. A saved opt-out during download prevents installation
when observed by the final check.

Git runs without inherited Git environment overrides, global/system config,
hooks or credential helpers. Only HTTPS transport is allowed. Metadata rejects
redirects and is limited to 256 KiB for releases and 32 MiB for the catalog,
with a 20-second socket timeout. Commands time out after 60 seconds (15 for
reload); their process groups are killed before staging cleanup.

## Results and limits

`updates.json` records `current`, `updated`, `unverified`, `local-changes`,
`disabled` or `failed`. `restart-pending` means installation succeeded but
shell reload failed; restart the shell to load the installed version. Failures
are retried at the next six-hour deadline (or the first startup on a new day).
An interrupted worker can leave
`checking` until that deadline; its lock is released when the process exits.

Atomic exchange needs Linux and a filesystem supporting it; staging and the
installation must be on the same filesystem. Final checks cannot lock out an
unrelated editor during the last instant before exchange. HTTPS responses from
GitHub and Omarchy remain trust dependencies. Later revocation does not uninstall
an existing version, and manifest validation does not prove runtime compatibility.

Publication and the first real public update test follow [Publishing](PUBLISHING.md).
Manual installation and updates through Omarchy’s CLI follow the repository’s
default branch. They do not use this release verifier or pin the installed code
to the catalog’s verified commit; see the [catalog verification contract](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/VERIFICATION.md).
