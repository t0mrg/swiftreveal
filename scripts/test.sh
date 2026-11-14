#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
# Command Line Tools ships Testing.framework outside the SDK framework search path.
developer_frameworks="$(xcode-select -p)/Library/Developer/Frameworks"
swift test --disable-sandbox --disable-xctest --enable-swift-testing --cache-path "$PWD/.build/cache" \
  -Xswiftc -F -Xswiftc "$developer_frameworks" \
  -Xlinker -F -Xlinker "$developer_frameworks" \
  -Xlinker -rpath -Xlinker "$developer_frameworks" \
  -Xlinker -rpath -Xlinker "$(dirname "$developer_frameworks")/usr/lib"
