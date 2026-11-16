SwiftReveal 0.8.0 — testing build, not published

- Preserve in-bounds JPEG/PNG imports; add Balanced/High quality/Compact/Original import resolution controls with bounded ImageIO decoding and orientation handling.
- Add Optimize presentation with before/after file-size estimates, optional JPEG recompression and opaque PNG-to-JPEG conversion, cancellation/stale-result guards and one-edit apply.
- Losslessly deduplicate embedded images and compress document storage when savings exceed both 5% and 1 KiB. Read legacy JSON, retain small JSON saves, and export Editable JSON for older-version compatibility.
- Add integrity/length/version checks, bounded decoding, storage/image regression tests and a compressed example deck.

Image optimization is optional for existing slides. SVG source and transparency are retained. Efficient storage requires SwiftReveal 0.8 or later; original JSON copies remain compatible subject to supported slide features. No public release, tag, push or Homebrew update has been performed.
