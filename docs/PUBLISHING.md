# Publishing

Author: Sarr. Preserve the root MIT license, `vendor/omarchy/LICENSE` and the
MIT notices in `tests/protocols/`.
The repository is `Sarr77/WindowPeek`; the plugin ID is `sarr.windowpeek`.

Prepare and test locally first. Before any publication, obtain approval for the
exact commit, complete diff, final title, text, metadata, links and attachments,
and each destination. Commit creation also requires permission. Approval for
one version does not cover later edits.

1. Run `python3 tools/check.py` and the isolated lifecycle test described in
   [Testing](TESTING.md). Complete the native checks for changed interactions.
   Inspect the package, final source tree, both README versions and the
   [preview artwork](PREVIEW.md).
2. After approval, publish that exact commit to `Sarr77/WindowPeek` and pass
   public CI. Keep `main`, the manifest version and the release tag on this
   same commit through catalog review.
3. With separate approval of the exact release title, Patch Notes and every
   attachment, enable release immutability, prepare the release as a draft and
   publish it with a `vX.Y.Z` tag pointing to that commit. Verify its public
   `immutable` flag, resolved tag SHA and manifest version. This makes one
   early GitHub release available; the release is not yet marked as verified
   by Omarchy. Do not arm `WINDOWPEEK_RELEASE_PLAN` for a release published
   before catalog review: the existing automation publishes drafts only after
   verification and must not publish or clear a plan for this release.
4. For this existing listing, use the
   [Plugin verification form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=verify-plugin.yml)
   and select **Verify and publish a newer upstream commit**. Supply
   `sarr.windowpeek`, `https://github.com/Sarr77/WindowPeek` and the full
   40-character SHA of the new repository HEAD, following the current
   [update instructions](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md#update-an-existing-listing).
5. Wait for the official catalog to bind both `listingValidatedCommit` and
   `verificationCommit` to that full SHA, with the other fields required by
   [Updates](UPDATES.md). The same release then shows a green dot on its next
   successful catalog check. It does not need a new tag, version or release.
   Green CI and issue activity alone are insufficient.

Any source change requires a new commit and verification. Never retarget a
published release or weaken the updater to get around missing catalog approval.
See GitHub's [immutable release documentation](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).

The previously published updater may still install a newly verified immutable
GitHub release under its saved automatic-install setting. It cannot offer the
new early-release preference or confirmation flow before this source is
installed. Account for that transition before approving publication; changing
this source cannot change older installed copies.

## First public update test

Only after publication, use a separate user profile with a clean older Git
installation that contains this updater. Save distinctive preferences, make
its scheduled deadline due, and leave the widget running with its panels closed.
Let the production scheduler discover the newer published release. Check the badge color,
the version and the commit displayed in the prompt; explicitly confirm the
installation. Do not inject metadata, force installation through a test
subclass or change the
version/files of the normal desktop installation.

Check the installed SHA, retained preferences, recorded deadline and successful
shell restart. Keep this result separate from local tests, which use disposable
repositories and simulated service responses. Until this test passes, a public
end-to-end confirmed update remains unverified.
