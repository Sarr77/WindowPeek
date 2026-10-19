# Updates

Open **Settings → Controls → Updates**. **Check now** looks for a newer published,
immutable WindowPeek GitHub Release. Drafts and prereleases are not offered.
The status shows the version, last check and whether the **exact commit** is
**Verified by Omarchy**. A green dot marks a verified commit; an amber dot
identifies an **Early WindowPeek GitHub release**. That release keeps its
version, tag and commit; its status turns green after Omarchy verifies the
commit. No second version is created. An unreachable catalog is never treated
as approval.
**View changes** opens the comparison on GitHub. When no update is available,
**Version history** opens the public GitHub Releases page.

## Choosing when to install

WindowPeek checks metadata every six hours while its panels are idle. A new
update appears as a badge on the bar and a notice in the expanded window list.
Opening the expanded panel can show a one-time prompt for that release stage. No check
or installation runs merely because you open the panel or Updates page.

The prompt offers **View changes**, **Install now**, **Later** and **Skip version**.
**Later** keeps the badge so you can return when ready. **Skip version** hides
the badge and prompt for that version at its current verification stage, but
leaves **Install now** available on the Updates page; **Show this version again**
reverses the skip. If Omarchy later verifies a skipped early release, the same
version and commit return with a green dot and can prompt once more. A newer
version can notify you too. The bar's dot follows the same verification status
as the page and prompt.

**Early GitHub releases** starts enabled. Turn it off to hide amber offers from
the bar, prompt and Updates page. **Check now** still checks GitHub, but offers
only a release verified by Omarchy. If the newest release is still early, a
newer-than-installed release matching the catalog's verified commit can be
offered instead. If the early release is later verified, that same release
appears green after the next check. Switching the option back on refreshes the
latest-release check. The installer enforces the choice again before replacing
the plugin.

**Install now** confirms the offered version in WindowPeek. The exact commit
is retained internally and checked again before installation. The
worker refuses to install a changed release or tag. If the cached offer changes
while the prompt is open, the Updates page asks you to review it again. The
worker rechecks the release and, for an update displayed as verified, the
catalog before replacing the plugin. An early WindowPeek release can still
be installed after your explicit confirmation when that option is enabled.
Installation restarts the Omarchy bar to load the new code; a failed restart
is reported separately.

The footer's **Automatic updates** switch and **Update notifications** on the
Updates page control the same *notification* preference. It starts enabled on a
new installation. Turning it off stops scheduled checks and hides the badge;
**Check now** still works. The name of the footer switch is retained, but it
does not authorize unattended installation. A previously saved **Verified
updates** choice no longer starts background installation.

## Protection and storage

Installation requires a clean, standard Git checkout of `Sarr77/WindowPeek`.
Development symlinks, forks, local modifications, ahead copies and untracked
files are not replaced. The checked commit must be a descendant of the
installed commit, and the version cannot go backwards. The worker fetches into
a fresh staging directory on the same filesystem, rejects symlinks and
submodules, checks Git objects and file bytes, validates the manifest and
Omarchy package, then atomically exchanges the plugin directories. Failure
before exchange leaves the installed code in place.

The worker checks the latest published release and its exact tag again before
exchange. A green status requires the official catalog's verified snapshot to
match its commit both during discovery and installation. An amber status is
never represented as verified. When early releases are disabled, the installer
also requires a fresh catalog match before exchange. GitHub and the Omarchy
catalog remain network trust dependencies; a catalog decision can change after
a check.

Preferences and update state live in `$XDG_STATE_HOME/windowpeek/` (normally
`~/.local/state/windowpeek/`), outside the replaceable plugin tree. The state
includes `preferences.json`, `manual-updates.json` and the shared
`updates.lock`; an old `updates.json` may remain from earlier releases. Saved
choices survive restarts and reinstalls. Checks and installation use the same
lock, so two monitors cannot install at once. There is no resident update
service.

If a worker is interrupted, use **Refresh status** after it stops. An
installation that succeeds but cannot restart the bar reports that
the bar needs a manual restart. See [Publishing](PUBLISHING.md) for how releases
and catalog verification are prepared.
