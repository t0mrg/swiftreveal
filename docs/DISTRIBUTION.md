# Distribution

SwiftReveal follows the same distribution pattern as MarimoDesktop: ZIP assets on GitHub Releases and a cask in `t0mrg/homebrew-tap`. It ships separate Apple silicon and Intel archives, with macOS 14 as the deployment target.

## First publication from a Mac with GitHub access

Install GitHub CLI (`brew install gh`), then authenticate (`gh auth login`). For an HTTPS login, allow workflow files (`gh auth refresh -s workflow`) and configure Git to use it (`gh auth setup-git`). Your account needs push access to `t0mrg/swiftreveal` and `t0mrg/homebrew-tap`. Confirm the audited source is committed on `main` and `origin` is `https://github.com/t0mrg/swiftreveal.git`.

Run:

```sh
./scripts/publish-release.sh
```

This runs the Swift and packaging tests, builds both architectures from neutral temporary paths, verifies ad-hoc signatures, generates checksums and a cask, pushes `main`, creates a draft GitHub release for the exact source commit, uploads assets, publishes the release, and creates or updates only `Casks/swiftreveal.rb` in your existing tap. Existing release assets are never silently overwritten. No GitHub or Apple credentials are stored in this repository.

Once a version is published, increment `CFBundleShortVersionString` and `CFBundleVersion` in `packaging/Info.plist`; never move a published tag or replace its release assets.

If upload is interrupted, finish the draft through GitHub's release page or `gh release upload`; do not change archives whose checksums have already been published. If the tap update fails, copy `swiftreveal.rb` from the published release into `Casks/swiftreveal.rb` in the tap and commit it. Publish a new release when the source changes.

## Subsequent GitHub Actions releases

The tests workflow runs on pushes to `main` and pull requests. The release workflow runs when a `v*` tag is pushed or when manually dispatched. It tests, builds both architectures, uploads build artifacts and publishes a release. A tag must match the version in Info.plist.

For automatic tap updates, add a fine-grained `TAP_GITHUB_TOKEN` Actions secret to `swiftreveal` with Contents read/write access to **only** `t0mrg/homebrew-tap`. The normal workflow token publishes assets to `swiftreveal`; it cannot write another repository. Without the optional secret, releases still publish and include a ready-to-copy cask. The local publishing script needs no Actions secrets because it uses your `gh` login.

Use either the local publishing script or a tag-triggered release for a version, not both. The local script lets GitHub create the release tag after pushing main, avoiding a concurrent tag-push workflow.

## Installing

Install the released app:

```sh
brew install --cask t0mrg/tap/swiftreveal
```

Upgrade an existing installation with `brew update` followed by `brew upgrade --cask t0mrg/tap/swiftreveal`. The first command refreshes metadata; the second installs the version recorded in the updated cask.

Alternatively, download the matching architecture ZIP from the latest GitHub release. The cask verifies the SHA-256 and installs the app; it does not remove macOS quarantine or change security settings. This intentionally improves on the older cask's automatic quarantine removal. Because the app is not notarized, first launch may need **System Settings → Privacy & Security → Open Anyway** after trying to open it.

A smoother first launch requires Apple Developer Program membership, a Developer ID Application signing certificate and notarization credentials. Those have not been provided. Signing/notarization must happen before computing checksums and publishing assets. Do not commit certificates, keys, credentials or provisioning files.
