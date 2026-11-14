# SwiftReveal development plan

## Goal
A local, native macOS slide editor for professional presentations. Users edit structured content and choose layouts; the app owns coordinates, spacing, typography and alignment.

## First testable release (0.1)
- Native document app, macOS 14+, Apple silicon build using Swift Package Manager.
- Slide navigator, add/duplicate/delete/reorder, native content inspector and live WebKit preview.
- Eight curated layouts: title, statement, two columns, figure with commentary, cards, metrics, table, and figure.
- Text, callout, metric, table and embedded image blocks. Figures use fit/crop. Tables accept tab-separated clipboard content.
- Consistent themes, configurable column split and density, presenter notes.
- Versioned portable JSON documents with embedded assets, standard Save/Open and undo/redo.
- Offline presentation, self-contained HTML export powered by vendored reveal.js, and PDF export through WebKit/PDFKit.
- Measured overflow feedback, without silently shrinking text to fit.
- Sample deck, automated model/render/export tests, reproducible .app build script and manual acceptance checklist.

## Architecture
SwiftRevealCore: Codable/Equatable/Sendable model, validation and deterministic HTML renderer. SwiftRevealApp: SwiftUI document shell, content inspector, WebKit bridge, presenter and PDF export. No service, account, API key or network requirement at runtime. The renderer escapes content and restricts image URLs to supported embedded formats. Model changes increment a schema version when compatibility changes.

## Work sequence
1. Establish repository, data contract and this plan.
2. Parallel implementation: core renderer/sample/tests; native inspector; preview/presentation/PDF integration. Main agent implements document shell and packaging.
3. Integrate, compile and fix build issues. Run unit tests and render smoke tests on the actual Mac.
4. Exercise persistence, exports and long-content behavior. Inspect screenshots/PDF and fix material defects.
5. Commit source and validation notes. Produce dist/SwiftReveal.app and a zipped build for testing.

## Acceptance criteria
- Clean build and automated tests pass.
- New sample opens as an editable document. Changes survive save/reopen.
- Layout changes preserve content. Slide operations maintain unique identities.
- Exported HTML works offline and has working presentation navigation.
- PDF has one 16:9 page per slide, with content and figures present.
- Oversized content produces visible warnings rather than hidden silent data loss.
- Errors are surfaced and export does not overwrite source documents.
- Final app launches on this Mac. Build is locally ad-hoc signed; notarization and distribution signing are outside this first release.

## Deliberately deferred
Arbitrary HTML/PPTX import, editable PPTX export, collaboration, AI generation, arbitrary drawing, animations editor, chart authoring, image annotations and universal layout solving. Research charts can be imported as high-resolution images. PDF/SVG import may be normalized to an embedded bitmap for reliable preview/export.

## Build environment
The Mac has Swift 6.3.3 and command line developer tools, but no full Xcode. Use swift build/test and a scripted .app bundle; no Xcode project is required. Target macOS 14 APIs and avoid dependencies requiring Xcode or remote resolution.

## Delivery status

The first testing release is implemented, with a signed app bundle, editable example, offline HTML example, reproducible build scripts and 16 passing unit tests. Native launch and the first preview were checked. Full interactive/visual and PDF runtime checks are pending because GUI automation was blocked by host permissions. See docs/VALIDATION.md for the precise evidence and the in-app integration-check command.

## Next development priorities

1. Complete the in-app integration checks and user acceptance checklist on the host Mac. Fix any export or editing defects before expanding scope.
2. Evaluate the editor against real research figures, dense evidence tables and long scientific titles, especially at projected-screen reading distances.
3. Add structured HTML import: recognize supported text, cards and tables, preserving custom charts as figures. Clearly report unsupported elements. General arbitrary HTML round-trip editing remains a separate project.
4. Improve table width controls, starter-deck selection and presenter display behavior in response to actual usage.

## Appearance update (0.2)

- Expand to nine themes, backed by one palette definition shared between editor controls and HTML rendering.
- Add optional, backward-compatible block colour overrides with per-field and whole-block resets.
- Embed per-slide background images with fit/fill, overlay controls and foreground colour.
- Start new documents with only an empty title slide; retain the tutorial as a separate example.
- Replace approximated navigator drawings with cached WebKit-rendered thumbnails. Include theme, slide content, background, footer and slide numbering in invalidation, and cancel obsolete queued requests.
- Test old-document decoding, appearance persistence, safe CSS values and all rendering/export paths. Extend the in-app integration suite for computed colours and thumbnails.

## Typography and CSS update (0.3)

- Store optional slide/block font factors, defaulting to 1 em for older documents. Apply compound factors to all text while preserving fixed slide geometry. Measure computed typography before mutation so edited CSS also scales once.
- Add a conservative rich-text HTML allowlist alongside Markdown. Reconstruct allowed tags/attributes, strip dangerous containers and resource/event/style attributes, and preserve entities/scientific notation. Hash trusted scripts in the content security policy.
- Store deck CSS and theme name inside the portable document. Append CSS safely after the base stylesheet and include CSS in thumbnail invalidation.
- Add a native CSS editor with live preview, base palette, snippets and named reusable theme snapshots, plus portable theme import/export.
- Extend tests for compatibility, typography, sanitization, script hashes and theme persistence. Extend in-app computed-style integration checks; rebuild and sign the app for testing.

## Public release preparation (0.4)

- Use generic examples and a descriptive Azure palette name.
- Add MIT licensing while preserving upstream notices.
- Provide icon concepts for review.
- Build from a neutral disposable directory and strip release debug symbols.
- Audit source, generated examples, release files and Git objects. Establish a clean initial public history with generic project metadata, and retain no obsolete local history or tags.
