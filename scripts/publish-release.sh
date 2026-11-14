#!/bin/bash
# Publish audited source, release binaries and the Homebrew cask using your gh login.
set -euo pipefail
cd "$(dirname "$0")/.."
repo="t0mrg/swiftreveal"
tap_repo="t0mrg/homebrew-tap"
command -v gh >/dev/null || { printf 'Install GitHub CLI first: brew install gh\nThen run: gh auth login\n' >&2; exit 1; }
gh auth status >/dev/null
if [[ "$(git branch --show-current)" != main ]]; then
    printf 'Switch to main before publishing.\n' >&2; exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
    printf 'Commit your source changes before publishing.\n' >&2; exit 1
fi
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' packaging/Info.plist)"
tag="v$version"
if git rev-parse "$tag" >/dev/null 2>&1 && [[ "$(git rev-list -n 1 "$tag")" != "$(git rev-parse HEAD)" ]]; then
    printf 'Tag %s points at another commit; increment the version before releasing.\n' "$tag" >&2; exit 1
fi
# This script creates its release through gh after pushing main. It does not push
# a tag separately, which would also trigger the release workflow.
./scripts/prepare-release.sh
git push -u origin main
if ! git rev-parse "$tag" >/dev/null 2>&1; then git tag "$tag"; fi
# gh creates the remote tag from the exact pushed source; no separate tag push is needed.
if ! gh release view "$tag" --repo "$repo" >/dev/null 2>&1; then
    gh release create "$tag" --repo "$repo" --target "$(git rev-parse HEAD)" \
        --title "SwiftReveal $version" --notes-file docs/RELEASE_NOTES.md --draft
fi
# Upload fails rather than replacing already-published assets with different checksums.
gh release upload "$tag" dist/SwiftReveal-macOS-arm64.zip dist/SwiftReveal-macOS-x86_64.zip dist/SHA256SUMS dist/swiftreveal.rb --repo "$repo"
gh release edit "$tag" --repo "$repo" --draft=false
# Preserve every other cask and include a SHA lease when updating an existing entry.
cask_sha="$(gh api "repos/$tap_repo/contents/Casks/swiftreveal.rb" --jq .sha 2>/dev/null || true)"
python3 - "$version" "$cask_sha" <<'PY'
import base64, json, sys
from pathlib import Path
payload = {'message': f'Update SwiftReveal to {sys.argv[1]}',
           'content': base64.b64encode(Path('dist/swiftreveal.rb').read_bytes()).decode()}
if sys.argv[2]:
    payload['sha'] = sys.argv[2]
Path('dist/tap-update.json').write_text(json.dumps(payload))
PY
gh api --method PUT "repos/$tap_repo/contents/Casks/swiftreveal.rb" --input dist/tap-update.json >/dev/null
printf '\nPublished https://github.com/%s/releases/tag/%s\nInstall: brew install --cask t0mrg/tap/swiftreveal\n' "$repo" "$tag"
