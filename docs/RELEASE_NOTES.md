SwiftReveal is a native macOS editor for structured slide presentations, with eight layouts, nine themes, live slide previews, figures, tables and offline reveal.js HTML/PDF export.

This release includes the Azure stacked-slides app icon, proportional slide/block font scaling, safe HTML alongside Markdown, custom deck CSS and reusable themes. Presentations use portable `.swiftreveal` JSON documents with embedded figures.

Download the `arm64` ZIP for Apple silicon or the `x86_64` ZIP for Intel. Requires macOS 14 or newer. Unzip and move SwiftReveal.app to Applications. SHA256SUMS contains the archive checksums; swiftreveal.rb is the matching Homebrew cask.

The app is ad-hoc signed and is not yet Apple-notarized. macOS may block the first launch; use System Settings → Privacy & Security → Open Anyway after attempting to open this trusted download. Full visual and PDF runtime checks are still pending; see docs/VALIDATION.md.
