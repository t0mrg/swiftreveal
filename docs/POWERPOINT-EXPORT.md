# Native PowerPoint export

## Implementation plan

1. **Rendering and file generation.** Bundle an offline, pinned PptxGenJS runtime. Measure the existing HTML renderer in WebKit at the deck's logical size after fonts, images and Mermaid finish rendering. Translate those measurements into editable text, shapes, tables and pictures rather than slide screenshots. Keep both aspect ratios, notes, colours, font scaling and backgrounds, including translucent overlays. Preserve Mermaid as styled SVG with a PNG compatibility fallback.
2. **Reusable layouts and app integration.** Generate eight named PowerPoint masters/layouts from the current theme and SwiftReveal's starter slides, with editable placeholders for new slides. Add PowerPoint to the export menu, with atomic writes, bounded rendering operations and clear errors. Keep the exporter offline and user markup outside the trusted script boundary.
3. **Verification and testing build.** Exercise every layout, rich text, native tables, backgrounds, Mermaid, both aspect ratios and custom styling. Check the resulting ZIP/XML structure, layout references, placeholders, native objects and image relationships. Run the existing Swift tests and build a signed local testing app. Commit each completed stage on `feature/powerpoint-export`.

## Fidelity and editing

PowerPoint has a different text/layout engine. Export uses measured positions and explicit rich text formatting. System UI fonts are mapped to Helvetica Neue; the receiving computer needs the corresponding fonts, or PowerPoint will substitute them. Fonts are not embedded. SVG diagrams and original pictures remain pictures, rather than editable diagram nodes. Arbitrary CSS effects without a PowerPoint equivalent cannot be guaranteed. Native table cells remain editable; layout masters provide starting points for extending the deck rather than a round-trip import format.

## Testing

PowerPoint export is included in **0.10.0 (15)**. The app is ad-hoc signed and is not notarized. Releases include Apple silicon and Intel builds plus the Homebrew cask.

1. Quit any other SwiftReveal instance, then run `open dist/SwiftReveal.app` from this repository.
2. Open your own deck or `dist/PowerPoint-Testing/PowerPoint-Checks.swiftreveal`.
3. Choose **Export → PowerPoint…**. Open the `.pptx` in PowerPoint and edit text, a bullet, a table cell and a coloured panel. Check background image opacity and the SVG diagram.
4. In PowerPoint, use **Home → New Slide** to choose a named **SwiftReveal** layout. Use **View → Slide Master** to inspect or edit the layouts. The file contains eight named layouts under a shared slide master, which is PowerPoint's normal structure for related designs.

Existing slides retain individually measured objects. Layouts provide templates for adding slides; applying a different layout does not reflow existing objects. New layout placeholders use the theme's default split, density and typography, rather than inheriting a particular slide's overrides. Slide counts on existing slides are exported as text; update them after extending the deck if needed.

Build and repeat automated verification:

```sh
scripts/test.sh
scripts/build-app.sh
dist/SwiftReveal.app/Contents/MacOS/SwiftReveal --powerpoint-test /tmp/SwiftReveal-PowerPoint-QA
python3 scripts/check-powerpoint.py /tmp/SwiftReveal-PowerPoint-QA
```

The JavaScript runtime is already vendored; building the app requires no npm install or network access. To rebuild that runtime after changing its source, run `npm ci && npm run build` in `packaging/powerpoint`. The pinned browser dependencies passed npm audit with no advisories at implementation time.

Validation: 113 Swift tests passed. The focused native harness exported both aspect ratios and all eight layouts, including native tables, rich-text bullets, a translucent background and Mermaid. It also verified clear failure on invalid Mermaid and preservation of a destination file on failure. The standard-library Python checker verifies all ZIP parts/relationships, paragraph validity, native objects, placeholder types, fonts/geometry-related structure, overlay alpha, diagram relationships and notes. Independent LibreOffice renders were inspected with the matching system fonts; eight extra slides were created from the exported layouts and rendered. Microsoft PowerPoint itself is not installed on the development machine, so testing in PowerPoint remains necessary, particularly for font substitution and new picture/table insertion.

The broader pre-existing WebKit smoke suite reports three failures on this machine: `SVG intrinsic dimensions 1`, `SVG intrinsic dimensions 2`, and `Presentation JavaScript`. All three were reproduced in an isolated, unchanged `main` checkout (120 checks). They are not introduced by this exporter. The dedicated PowerPoint checks and Swift tests pass.
