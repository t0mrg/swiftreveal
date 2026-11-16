# Testing and acceptance

## Automated checks

Run `./scripts/test.sh` for schema/version validation, serialization with embedded image bytes, identifier uniqueness on duplication, TSV parsing and renderer safety/layout contracts. Renderer tests cover preserved content, escaping, embedded resources and fixed slide dimensions.

Run the built application's `--smoke-test /absolute/output/directory` mode for real WebKit rendering and PDF export. It uses the production renderer/exporter, verifies page count and 16:9 bounds, checks sample layouts and generates review images. It does not claim to test native interactions such as File → Save or undo.

If a restricted shell cannot launch GUI apps, launch SwiftReveal normally and choose **Help → Run Integration Checks…**. The same suite runs without quitting the editor, and saves its report and artifacts to `/tmp/SwiftReveal-QA`.

## Manual acceptance checklist

- [ ] Launch the bundled app from Finder.
- [ ] Edit title and body, then save, close and reopen the document.
- [ ] Undo and redo text and structural edits.
- [ ] Create each of the eight layouts and change layout without losing blocks.
- [ ] Duplicate a slide and edit the copy independently.
- [ ] Reorder and delete slides. Last slide cannot be deleted.
- [ ] Select blocks both from the preview and inspector.
- [ ] Add, duplicate, reorder and delete blocks.
- [ ] Import a real research figure; verify fit/crop, caption, persistence and PDF clarity.
- [ ] Paste a table with empty cells and long labels. Verify headers and all rows.
- [ ] Add excessive text/table rows and confirm a warning, then resolve it with Split slide.
- [ ] Switch themes and column split; verify that content is preserved.
- [ ] Present from a middle slide. Check arrows, speaker notes, full screen and Esc.
- [ ] Export HTML, disconnect networking and open it in Safari.
- [ ] Export PDF; check every page in Preview.
- [ ] Open a corrupt document or unsupported schema; confirm a useful error.
- [ ] Open two presentations; confirm that editing/presenting one does not affect the other.

## Appearance acceptance (0.2)

- [ ] File → New starts with a title slide and no blocks; existing documents retain their content.
- [ ] Switch among all nine themes, including Midnight; verify the main preview, table stripes and navigator thumbnails agree.
- [ ] Set a callout background/text/accent, then change the deck theme; overrides remain in place.
- [ ] Reset one colour, then Reset all; the block follows the current theme again.
- [ ] Set table body and header text colours separately; the header retains its own colour.
- [ ] Import a background; try fit/fill, overlay colour/strength and slide text colour.
- [ ] Duplicate/save/reopen a slide with a background and styled blocks; all settings persist.
- [ ] Export styled slides with backgrounds to HTML and PDF; verify their appearance.
- [ ] Edit rapidly and reorder/delete slides while thumbnails render; ensure the navigator shows current content.

The in-app integration suite also checks actual computed theme/table colours, thumbnail changes between themes and background decoding. These runtime checks require a normal Mac GUI session.

## Typography and CSS acceptance (0.3)

- [ ] Change slide font scale to 1.2 em; compare title, body, metric, captions, table headers/cells and footer.
- [ ] Set a block to 0.8 em; only that block scales further, retaining its internal hierarchy.
- [ ] Set a CSS font size in pixels; verify the scale controls still multiply it once, including nested inline markup.
- [ ] Verify fixed slide margins, image sizing and grid geometry remain stable while text reflows.
- [ ] Mix Markdown with `<em>`, `<sup>`, `<sub>`, `<mark>`, classes and body HTML tables.
- [ ] Enter a script/event/style payload; confirm it is removed and does not execute.
- [ ] Open CSS & themes, edit CSS and change the preview slide; verify live updates and navigator invalidation.
- [ ] Save a named theme, create another presentation and apply it; verify the old deck remains unchanged.
- [ ] Export/import a theme JSON file. Verify an exported presentation retains its CSS after moving it elsewhere.
- [ ] Save/reopen and undo/redo font and CSS edits. Old presentation files still open.
- [ ] Compare HTML presentation and PDF with the editor after changing fonts/CSS.

## Release evidence

The actual commands run and their outcomes are recorded in `docs/VALIDATION.md` at delivery. Unchecked manual items are tasks for user testing, not implied passes.

## Alignment, diagrams and code acceptance (0.5)

- [ ] Centre title/subtitle horizontally, vertically, then both; check no-content title slides with backgrounds and footers.
- [ ] Add a content block: normal layout returns without losing the stored alignment options.
- [ ] Add a Mermaid diagram; edit nodes, arrows, labels and direction. Compare main preview and thumbnail.
- [ ] Test flowchart/DAG branches and labelled edges, including Unicode and punctuation in quoted labels.
- [ ] Enter invalid Mermaid: verify a readable error and that PDF export preserves an existing output file.
- [ ] Confirm initialization directives, click handlers and external image/link content cannot escape the slide.
- [ ] Export HTML and open offline: all graph nodes, edges and arrowheads appear.
- [ ] Export PDF: diagram labels and edges appear; inspect a zoomed page for vector sharpness.
- [ ] Try Python, R, SQL and plaintext fences with tabs, blank lines, literal HTML and long lines.
- [ ] Change slide and block scales and theme; code stays readable and diagrams keep labels inside nodes.
- [ ] Save/reopen and duplicate slides containing diagrams and alignment options.

## Menu and insertion acceptance (0.5.1)

- [ ] Save and quit the previous app, then open the exact rebuilt app from dist.
- [ ] Open File/Edit/Window menus and execute New/Save/Undo as applicable.
- [ ] Add slides through both sidebar and toolbar popovers, with all layout choices.
- [ ] Add every block kind through its popover; verify selection and undo/save/reopen.
- [ ] Repeat while thumbnails render and after closing presentation/export windows.
- [ ] Confirm thumbnail/PDF render hosts never become key/main or intercept clicks.
- [ ] If menu-bar failure persists, open Diagnostics and inspect modal/activation/window state and menu-tracking events.

## Cross-window slide transfer and Mermaid labels (0.6 testing)

- [ ] Open a source presentation and use New window/Open to create a separate destination; confirm edits remain independent.
- [ ] Copy a single slide, a Shift-selected range and disjoint Command-selected slides, using buttons and navigator ⌘C/⌘V.
- [ ] Paste above the first/middle/last target and above a multi-selection; verify source order and destination position.
- [ ] Set different source/destination themes and deck CSS. Unset colours follow the destination; custom block/table colours and backgrounds remain unchanged.
- [ ] Copy image, table, Mermaid, background, notes and scaled text; save/reopen the destination and verify all content.
- [ ] Paste twice into the same deck and back into the source; edit one copy and confirm others are independent.
- [ ] Undo/redo one multi-slide paste as a unit; verify selection remains valid after undo, redo, deletion and reordering.
- [ ] Copy/paste text in the inspector: standard text shortcuts must not copy/paste slides there.
- [ ] Test Process, long and multiline Mermaid labels in rectangles/diamonds/rounded nodes, including light/dark themes and slide/block scaling.
- [ ] Compare Mermaid label centring and containment in preview, navigator, offline HTML and PDF.

Obtain user acceptance after the implementation commit before deploying a release. The user accepted the 0.6.0 testing build and authorized publication.

## SVG images and backgrounds (0.7 testing)

- [ ] Import Examples/SVG-Figure.svg as a figure and Examples/SVG-Background.svg as a background; inspect source text, arrows, gradients and clipping.
- [ ] Try representative SVG exports from plotting/design tools, including defs/use glyphs, masks, local CSS and transparent artwork.
- [ ] Verify inspector previews and navigator thumbnails; switch themes, fit/crop, overlays and image replacements between SVG/raster formats.
- [ ] Save/reopen, duplicate and copy/paste SVG slides across decks; source stays SVG and custom slide settings remain.
- [ ] Export offline HTML and PDF; zoom in on simple paths/text and inspect complex filters/font substitutions.
- [ ] Run Help → Run Integration Checks for real WebKit decoding, SVG colour/clip pixels, background overlays and a PDF no-raster-XObject check for a purely vector fixture.
- [ ] Import an SVG with a script/external image or unsupported feature: expect a readable error and no replacement of the existing image.
- [ ] Confirm existing PNG/JPEG/TIFF/PDF imports continue to work.

This testing build is not a new public release until separately authorized.
