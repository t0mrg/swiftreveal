#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/test.sh
python3 -m unittest discover -s Tests/PackagingTests -v
# Leave an Apple silicon .app in dist; both architectures have separate ZIPs.
SWIFTREVEAL_ARCH=x86_64 ./scripts/build-app.sh
SWIFTREVEAL_ARCH=arm64 ./scripts/build-app.sh
python3 scripts/release-manifest.py
