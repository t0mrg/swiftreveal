SwiftReveal 0.10.0

- Export editable PowerPoint presentations entirely offline using Export → PowerPoint.
- Keep text, rich-text bullets, coloured panels, shapes and tables editable as native PowerPoint objects, with measured slide geometry and both aspect ratios.
- Preserve Mermaid diagrams as SVG pictures with PNG compatibility previews.
- Include eight reusable SwiftReveal layouts in PowerPoint’s Slide Master view, with text, picture and content placeholders for extending a presentation.
- Preserve background images with separate translucent overlays, speaker notes, cover gradients and the deck’s theme palette.

Fonts are not embedded. The default export uses Helvetica Neue; the receiving computer needs the same fonts to avoid substitutions. Advanced custom CSS may differ. Exported slides retain independently positioned objects; applying a different PowerPoint layout does not automatically reflow them.

Requires macOS 14 or newer. Apple silicon and Intel downloads are included. The app is ad-hoc signed and is not yet notarized; first launch may require Privacy & Security → Open Anyway.

Install:

    brew install --cask t0mrg/tap/swiftreveal

Upgrade (quit SwiftReveal first):

    brew update
    brew upgrade --cask t0mrg/tap/swiftreveal
