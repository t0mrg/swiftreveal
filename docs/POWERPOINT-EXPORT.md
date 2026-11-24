# Native PowerPoint export

## Implementation plan

1. **Rendering and file generation.** Bundle an offline, pinned PptxGenJS runtime. Measure the existing HTML renderer in WebKit at the deck's logical size after fonts, images and Mermaid finish rendering. Translate those measurements into editable text, shapes, tables and pictures rather than slide screenshots. Keep both aspect ratios, notes, colours, font scaling and backgrounds, including translucent overlays. Preserve Mermaid as styled SVG with a PNG compatibility fallback.
2. **Reusable layouts and app integration.** Generate eight named PowerPoint masters/layouts from the current theme and SwiftReveal's starter slides, with editable placeholders for new slides. Add PowerPoint to the export menu, with atomic writes, bounded rendering operations and clear errors. Keep the exporter offline and user markup outside the trusted script boundary.
3. **Verification and testing build.** Exercise every layout, rich text, native tables, backgrounds, Mermaid, both aspect ratios and custom styling. Check the resulting ZIP/XML structure, layout references, placeholders, native objects and image relationships. Run the existing Swift tests and build a signed local testing app. Commit each completed stage on `feature/powerpoint-export`.

## Fidelity and editing

PowerPoint has a different text/layout engine. Export uses measured positions and explicit rich text formatting. System UI fonts are mapped to Helvetica Neue; the receiving computer needs the corresponding fonts, or PowerPoint will substitute them. Fonts are not embedded. SVG diagrams and original pictures remain pictures, rather than editable diagram nodes. Arbitrary CSS effects without a PowerPoint equivalent cannot be guaranteed. Native table cells remain editable; layout masters provide starting points for extending the deck rather than a round-trip import format.

## Testing

Instructions and validation results will be added when the testing build is ready.
