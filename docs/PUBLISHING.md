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
   public CI. For this existing listing, use the
   [Plugin verification form](https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=verify-plugin.yml)
   and select **Verify and publish a newer upstream commit**. Supply
   `sarr.windowpeek`, `https://github.com/Sarr77/WindowPeek` and the full
   40-character SHA of the new repository HEAD, following the current
   [update instructions](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md#update-an-existing-listing).
3. Wait for the official catalog to bind both `listingValidatedCommit` and
   `verificationCommit` to that full SHA, with the other fields required by
   [Updates](UPDATES.md). Green CI and issue activity alone are insufficient.
4. Enable release immutability for the repository and prepare the release as a
   draft, attaching the approved files before publishing. Publish an immutable
   `vX.Y.Z` release whose tag points to that same commit
   and whose version matches `manifest.json`. Verify the public release's
   `immutable` flag, resolved tag SHA and catalog record after publication.

Any source change requires a new commit and verification. Never retarget a
published release or weaken the updater to get around missing catalog approval.
See GitHub's [immutable release documentation](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).

## First public update test

Only after publication, use a separate user profile with a clean older Git
installation that contains this updater. Save distinctive preferences, make
its scheduled deadline due, and leave the widget running with its panels closed.
Let the production scheduler fetch the real public release itself. Do not
inject metadata, force installation through a test subclass or change the
version/files of the normal desktop installation.

Check the installed SHA, retained preferences, recorded deadline and successful
shell restart. Keep this result separate from local tests, which use disposable
repositories and simulated service responses. Until this test passes, a public
end-to-end automatic update remains unverified.
