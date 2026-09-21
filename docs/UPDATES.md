# Automatic updates

Updates are enabled by default. The small switch in the panel footer saves the
choice for all monitors. Turning updates off requires confirmation; Cancel,
Escape and the default Enter leave them enabled. A failed save keeps the last
saved choice and shows an error. Repair an unreadable or damaged preferences
file before restarting the shell; it is never silently overwritten.

## Schedule and storage

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

## Release approval

Only a newer stable `vX.Y.Z` release from `Sarr77/WindowPeek`, marked immutable
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

## Installation checks

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
