SwiftReveal 0.9.0

- Choose 16:9 or 6:4 (3:2) in Deck settings. The selected canvas applies to previews, thumbnails, presentation mode and HTML/PDF exports; existing presentations retain 16:9.
- Import SVG figures and slide backgrounds while retaining their vector source and safe self-contained artwork.
- Import raster images efficiently with resolution presets; optimize existing images with before/after estimates and optional JPEG recompression or opaque PNG conversion.
- Save smaller presentations using lossless compression and image deduplication when worthwhile. Legacy JSON files still open; Export → Editable JSON remains available.
- Comprehensive README reference for presentation CSS classes, layout/state selectors, palette variables, code/diagram styling and practical overrides.

Includes all changes since 0.6.0. Efficient containers require SwiftReveal 0.8 or later; the 6:4 canvas requires 0.9 or later. Raster optimization is optional for existing slides, and SVG source and transparency are retained.

Requires macOS 14 or newer. Apple silicon and Intel downloads are included. The app is ad-hoc signed and is not yet notarized; first launch may require Privacy & Security → Open Anyway.

Homebrew upgrade (quit SwiftReveal first):

    brew update
    brew upgrade --cask t0mrg/tap/swiftreveal
