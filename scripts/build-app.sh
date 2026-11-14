#!/bin/bash
set -euo pipefail
export COPYFILE_DISABLE=1

# Build in a neutral, disposable path so binaries never embed the checkout path.
# Full Xcode is optional. Override SWIFTREVEAL_ARCH to choose a target architecture.
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_arch="${SWIFTREVEAL_ARCH:-$(uname -m)}"
configuration="${SWIFTREVEAL_CONFIGURATION:-release}"
case "$build_arch" in
    arm64|x86_64) ;;
    *) printf 'Unsupported architecture: %s\n' "$build_arch" >&2; exit 1 ;;
esac
release_root="$(mktemp -d /tmp/swiftreveal-release.XXXXXX)"
trap 'rm -rf "$release_root"' EXIT
source_dir="$release_root/source"
mkdir -p "$source_dir"
/usr/bin/rsync -a --exclude .git --exclude .build --exclude .swiftpm --exclude dist --exclude .DS_Store "$project_dir/" "$source_dir/"
cache_dir="$release_root/module-cache"
app_dir="$project_dir/dist/SwiftReveal.app"
mkdir -p "$cache_dir" "$release_root/cache" "$project_dir/dist"
export CLANG_MODULE_CACHE_PATH="$cache_dir"
export SWIFTPM_MODULECACHE_OVERRIDE="$cache_dir"

cd "$source_dir"
build_options=(--disable-sandbox --cache-path "$release_root/cache" --manifest-cache none --configuration "$configuration" --triple "${build_arch}-apple-macosx14.0" -Xswiftc -module-cache-path -Xswiftc "$cache_dir")
swift build "${build_options[@]}"
binary_dir="$(swift build "${build_options[@]}" --show-bin-path)"

# Only replace this script's generated bundle. Source documents live elsewhere.
rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/SwiftReveal" "$app_dir/Contents/MacOS/SwiftReveal"
cp "$project_dir/packaging/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/packaging/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$app_dir/Contents/PkgInfo"

resource_bundle="$binary_dir/SwiftReveal_SwiftRevealCore.bundle"
if [[ ! -d "$resource_bundle" ]]; then
    printf 'Required resource bundle missing: %s\n' "$resource_bundle" >&2
    exit 1
fi
cp -R "$resource_bundle" "$app_dir/Contents/Resources/SwiftReveal_SwiftRevealCore.bundle"
if [[ -d "$project_dir/Examples" ]]; then
    cp -R "$project_dir/Examples" "$app_dir/Contents/Resources/Examples"
fi
for notice in README.md LICENSE THIRD_PARTY_NOTICES.md; do
    if [[ -f "$project_dir/$notice" ]]; then
        cp "$project_dir/$notice" "$app_dir/Contents/Resources/$notice"
    fi
done

# Release executables contain neither local debug symbols nor source maps.
if [[ "$configuration" == release ]]; then
    /usr/bin/strip -S "$app_dir/Contents/MacOS/SwiftReveal"
fi
/usr/bin/plutil -lint "$app_dir/Contents/Info.plist"
/usr/bin/codesign --force --deep --sign - "$app_dir"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app_dir"
/usr/bin/ditto --norsrc --noextattr --noqtn -c -k --keepParent "$app_dir" "$project_dir/dist/SwiftReveal-macOS-$build_arch.zip"
printf '\nBuilt %s\nArchive %s\n' "$app_dir" "$project_dir/dist/SwiftReveal-macOS-$build_arch.zip"
printf 'Launch with: open "%s"\n' "$app_dir"
