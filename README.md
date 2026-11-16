# SwiftReveal

A native macOS editor for structured slide presentations. Edit content and select a layout; consistent rules handle margins, alignment, spacing and typography.

## Features

- Eight structured layouts with automatic margins, alignment and spacing.
- Multiple presentation windows, navigator multiselection and cross-presentation slide copy/paste above the target selection. Slides inherit the receiving theme while retaining custom colours and embedded content.
- SVG figure and background imports with embedded vector source, plus Mermaid flowcharts and causal DAGs rendered as offline SVG.
- Markdown, safe HTML and fenced code blocks with syntax highlighting and preserved indentation.
- Nine themes, per-block/table colours, slide background images, a deck CSS editor and reusable custom themes.
- Independent slide/block font scaling and horizontal/vertical title-slide centring.
- Efficient raster imports, an Optimize panel with quality/resolution controls, and lossless compressed saves with image deduplication.
- Live previews and navigator thumbnails, speaker notes, presentation mode, and self-contained reveal.js HTML/PDF export.

## Install

Download the appropriate ZIP from [GitHub Releases](https://github.com/t0mrg/swiftreveal/releases/latest): `arm64` for Apple silicon or `x86_64` for Intel. Unzip it and move **SwiftReveal.app** to Applications.

Install with Homebrew:

```sh
brew install --cask t0mrg/tap/swiftreveal
```

To upgrade an existing installation:

```sh
brew update
brew upgrade --cask t0mrg/tap/swiftreveal
```

`brew update` refreshes cask metadata; `brew upgrade` installs the new app version. Quit SwiftReveal before upgrading, then reopen it.

Requires macOS 14 or newer. The app is ad-hoc signed and is not yet notarized by Apple. If macOS blocks the first launch of this trusted download, attempt to open the app, then use **System Settings → Privacy & Security → Open Anyway**. Homebrew does not disable quarantine automatically.

See [distribution instructions](docs/DISTRIBUTION.md) for publishing releases and updating the cask.

## Run a local build

Open `dist/SwiftReveal.app`, then choose **New Document** (or **File → New**). New documents start with a single title slide and no content blocks. An editable tutorial deck remains available in `Examples/Getting-Started.swiftreveal`. Save your own copy with **File → Save** (`⌘S`). The app uses `.swiftreveal` files containing the presentation and embedded figures. Version 0.8 reads legacy JSON and can save a smaller, versioned binary container with deduplicated images and lossless LZFSE compression. Small decks remain plain JSON when a container would not save at least 5% and 1 KiB. The example chart and values are illustrative, not real-world data.

Release ZIPs are provided for both Apple silicon and Intel Macs. The local build script defaults to the architecture of the build machine; use `SWIFTREVEAL_ARCH=arm64` or `SWIFTREVEAL_ARCH=x86_64` to select one explicitly.

## Image efficiency and document size

Figure and background pickers have **Import quality** controls. **Balanced** limits the longest edge to 2560 pixels; **High quality** uses 4096 and **Compact** uses 1920. **Original pixels and format** retains JPEG/PNG source bytes. Images are never enlarged. JPEG/PNG images already within the chosen limit keep their original bytes by default. New JPEG imports stay JPEG; transparent PNGs remain PNG. TIFF/PDF conversion remains available, and SVG stays vector.

Use **Optimize** in the toolbar for existing presentations. The panel shows legacy JSON size, the estimated next-save size with unchanged images, and the estimated size after image optimization. Analyze different presets before applying. JPEG recompression is available at 85% quality for Balanced, 92% for High quality or 75% for Compact. **Compress opaque PNG as JPEG** is opt-in and best suited to photos; leave it off for plots, screenshots and line art. Transparent resized output remains PNG. **Original** performs no image changes and lets you benefit from lossless document storage alone.

Apply updates the document in one edit, with Undo support. Save with **⌘S** to write it. The optimizer works on each unique raster image once, preserves slide styles/metadata and leaves SVG or unsupported image formats unchanged. Import and optional compression avoid increasing image size unless a resolution limit or format conversion requires it.

Efficient saving stores identical image bytes once across figures and backgrounds. The storage envelope is losslessly compressed only when worthwhile, includes integrity checks, and is decoded with bounded sizes (512 MiB file/decompressed-envelope limits). Image optimization reduces the media itself; document compression/deduplication reduces `.swiftreveal` storage without changing image quality. HTML/PDF exports use the current in-memory images.

**Compatibility:** older presentations still open. Efficient containers require SwiftReveal 0.8 or later. Use **Export → Editable JSON…** for a conventional `.swiftreveal` JSON copy when sharing with older versions or inspecting the source. Saving does not recompress raster pixels repeatedly; JPEG/PNG quality changes happen during import or explicit optimization.

Measured on the included Getting Started example, lossless storage reduced 168,620 to 46,577 bytes (72.4%), with identical restored image data. A generated photo-like PNG fixture shrank from 995,880 to 329,325 bytes (66.9%) with optional JPEG conversion; a generated existing JPEG shrank from 382,284 to 269,675 bytes (29.5%). These are illustrative measurements, not guaranteed savings for every deck.

Open `Examples/Efficient-Storage.swiftreveal` to test compressed/deduplicated document reading. The original JSON example remains available. The developer utility can measure a file with `SwiftRevealTool measure-storage /absolute/presentation.swiftreveal`.

## Multiple windows and copying slides

Use **New window** above the slide navigator to create another presentation, or **Open…** to open existing `.swiftreveal` files in separate windows. File → New/Open and the usual macOS shortcuts remain available.

1. In the source window, click slides in the navigator. Use **⌘-click** for individual slides or **Shift-click** for a range.
2. Click **Copy** below the navigator, or press **⌘C** while the navigator has focus.
3. Switch to the receiving window and select the slide that should follow the pasted slides.
4. Click **Paste above**, or press **⌘V** while its navigator has focus.

Slides are copied in their original presentation order and inserted **above** the receiving selection. If multiple target slides are selected, insertion is above the earliest selected target in presentation order. The pasted slides become selected. Repeated paste creates independent copies with fresh identifiers.

The receiving presentation keeps its theme, deck CSS, author and footer. Per-block custom colours, table-header colours, embedded figures/backgrounds, text, notes, layouts and font settings are retained. Source deck CSS is not transferred; any custom CSS classes use the receiving deck's definitions.

The **Slides** menu also offers explicit slide-copy/paste actions with **⌥⌘C** / **⌥⌘V**, regardless of text-field focus. Ordinary **⌘C/⌘V** in text fields continues to edit text. Clipboard payloads are versioned and limited to 100 MB including embedded images.

## Create and edit

- Choose a slide on the left. Edit its title, subtitle and blocks in the inspector on the right.
- Click a block in the live preview to select its editor.
- Use **Add slide** to choose a composition. The eight layouts cover titles, statements, columns, figures with commentary, cards, metrics, tables and full figures.
- Changing a layout retains all content. Blocks flow in their existing order. Add, duplicate, reorder or delete blocks in the inspector.
- Right-click a slide to duplicate, move or delete it. Drag slides in the navigator to reorder them.
- Use **Deck settings** for the presentation title, author, theme and footer. Choose from nine themes: Azure, Ocean, Graphite, Forest, Ember, Plum, Sand, Midnight and Monochrome.
- Select a content block and use **Block colours** to change its background, text and accent colours. Tables also have header background and header text colours. Each colour can be reset independently to follow the theme, or use **Reset all**.
- Navigator thumbnails are rendered from the actual slides. Theme changes, custom block colours and background images update the thumbnails automatically.
- Use the column split and spacing controls to adjust composition. Text does not silently shrink when it becomes too long.
- When a slide needs more room, select a block and use **Split slide** to move it to a new slide, or shorten the content. Overflow warnings describe detected layout problems.
- Add speaker notes in the inspector. `⌘Z` / `⇧⌘Z` undo and redo document edits.

### Title alignment

On a title slide with no content blocks, use **Layout → Centre title horizontally** and/or **Centre title vertically**. The title, subtitle and section label move as a group. The two options work independently and remain saved with the slide. Adding a content block restores the normal title layout; remove all blocks to use the saved alignment again.

### Mermaid diagrams

Choose **Add block → Mermaid diagram** and edit its source in the inspector. Use `flowchart LR` for a left-to-right flowchart or `flowchart TD` for a top-down graph. For a causal DAG, use directed arrows without cycles; the editor does not validate causal assumptions or acyclicity.

```text
flowchart LR
    C[Confounder] --> X[Exposure]
    C --> Y[Outcome]
    X --> Y
```

Diagrams are rendered as SVG using bundled Mermaid, including in navigator thumbnails, offline HTML exports and PDF capture. Use **Full figure** for a large diagram or **Two columns** for a diagram with commentary. A heading and caption are optional. Syntax errors appear in the preview and prevent PDF export until corrected. Flowcharts/graphs are supported; other Mermaid diagram families and initialization directives are not enabled. Interactive links, external resources and embedded HTML are disabled.

Open `Examples/Diagrams-and-Code.swiftreveal` for editable examples of centred titles, a DAG and highlighted code.

### Code blocks

In a text block, put three backticks and a language name on a line, paste your code below, and close with three backticks on their own line. Tilde fences are also supported. For example:

````text
```python
def mean(values):
    if not values:
        return None
    return sum(values) / len(values)
```
````

Spaces, tabs and blank lines are preserved. Tabs display at four-space stops; long lines wrap visually without changing the stored code. Code starts at a 22 px slide font and follows slide/block font scaling. Highlighting runs locally when HTML is generated, so it also appears in PDF and offline HTML. Highlighted languages include Python, R, Swift, JavaScript, TypeScript, SQL, Bash, JSON, YAML, C/C++, C#, Java, Go, Rust, HTML and CSS. Unknown languages, unlabelled fences and `text`/`plaintext` render as plain code. Backticks around short inline expressions still work.

### Font scaling

Use **Slide font scale** under Layout to scale all slide text proportionately, including the title, section label, subtitle, block text, figures' captions, tables and footer. Select a block to use **Block font scale** for just that block's heading, body, caption and table text. Values are multipliers in em, from 0.25 to 4, with 1 em as the default. Slide and block values multiply: 1.2 em for the slide and 0.8 em for a block gives 0.96× text in that block. Reset returns the scope to 1 em. Images and slide geometry are not scaled; larger text can still need more room.

Scaling also applies after edited CSS, including CSS that specifies font sizes in pixels. Relative inline text, such as superscripts, retains its size relationship.

### Markdown and safe HTML

Text fields accept Markdown emphasis, strikethrough, inline code, bullets and numbered lists, alongside safe HTML. For example, `**bold <em>and italic</em>**`, `H<sub>2</sub>O`, `x<sup>2</sup>`, `<mark>highlight</mark>` or `<span class="emphasis">important</span>`. Body text also accepts paragraphs, headings, lists, blockquotes, preformatted code and HTML tables. Title/caption fields retain inline formatting and unwrap block containers.

Scripts and dangerous containers are removed along with their content. Event handlers, inline styles, images, links' URL attributes and other resource-loading attributes are stripped. Use figure blocks for images and CSS classes for custom text styling. Type entities such as `&alpha;` or `&le;`, and use inline backticks when you want HTML displayed literally.

### CSS and reusable themes

Open **CSS & themes** (the braces button) in the toolbar. Edit deck CSS on the left and choose a slide for the live preview on the right. CSS applies after the built-in theme, across the main preview, thumbnails, presentation, HTML export and PDF capture. Insert examples to get started, or style a retained HTML class, for example `.emphasis { color: #b24a20; }`.

Give the result a name and choose **Save as new theme**. It appears under **Apply saved theme** for reuse in other decks. Saving creates a snapshot; later edits affect the current presentation. Use a new name to save another version. Theme snapshots store the base palette and CSS, not your slide contents, per-slide scales or per-block overrides.

**Export theme** and **Import theme** share portable `.swiftrevealtheme.json` files. Saved themes live in SwiftReveal's Application Support folder, while every presentation embeds its own CSS and remains independent of those files. **Reset CSS** clears the deck's custom CSS while retaining its base theme. External resources are blocked, keeping exports self-contained.

### Figures

Select a figure block and import SVG, PNG, JPEG, TIFF or PDF, up to 20 MB. The first page of a PDF is used. JPEG/PNG imports keep their format and use the selected import-resolution preset; TIFF/PDF imports are converted to PNG. SVG imports retain static vector artwork and are not converted to PNG. Choose **Fit** to retain the whole figure, or crop to fill its frame. Add a caption/source below.

SVGs can also be chosen for slide backgrounds using the same fit/crop and overlay controls. Inspector previews, navigator thumbnails, offline HTML and PDF capture use the validated embedded image. Saving, duplication and slide copy/paste retain its vector bytes and MIME type.

Supported SVG artwork includes paths, shapes, text, CSS classes/styles, gradients, masks, clipping, filters and internal symbol/image references. Embedded PNG/JPEG images are supported. SVGs must be self-contained and static: scripts, animations, embedded HTML, external resources, web-font imports and unsupported CSS are rejected with an import error. Export text as paths when a particular font must look identical on other Macs.

Try `Examples/SVG-Figure.svg` and `Examples/SVG-Background.svg`, or open `Examples/SVG-Images.swiftreveal`. SVG source stays vector in the document and HTML; PDF rendering uses WebKit, so complex effects can require rasterization and should be checked at export.

### Background images

Use **Slide background → Choose background image…** in the inspector. The image is embedded in the document and included in HTML/PDF exports. Choose **Fill and crop** for a full-slide image or **Fit entire image** to preserve it all. Adjust the overlay colour and strength to keep the title and text readable, and choose the slide text colour. Callouts and tables keep their own theme colours unless you override them. Remove the image to return to the theme background. Backgrounds are set separately for each slide and retained when a slide is duplicated.

### Tables

Select a table block, copy cells from Excel or another spreadsheet, then use **Paste table**. The first row is the header. You can also edit tab-separated values directly. Empty cells are retained. Tables use consistent formatting and automatic column layout. Complex merged cells and per-column width controls are deferred. A long table should be divided across slides.

## Present and export

**Present** opens a separate presentation window from the current slide. Use the arrow keys to navigate, **S** for notes and **Esc** to close the presentation window. Use the green window button for native full screen.

**Export → HTML** creates a self-contained offline reveal.js presentation, with scripts, styling and images embedded. It can be opened in a browser or shared as a single file. Notes are included in the HTML file; remove confidential notes before sharing.

**Export → PDF** creates one 16:9 page per slide using the same WebKit renderer. Text remains vector text. Embedded figures retain their imported raster resolution. Layout overflow should be resolved before export: a fixed slide cannot display unlimited content.

Export creates a separate file. Save the editable `.swiftreveal` document as well.

## Build and test

```sh
./scripts/test.sh
./scripts/build-app.sh
./dist/SwiftReveal.app/Contents/MacOS/SwiftReveal --smoke-test "$PWD/.build/qa"
```

Command-line developer tools and Swift 6+ are sufficient; full Xcode and external package downloads are not required. Tests keep compiler caches inside the project; release builds use disposable neutral temporary paths. The smoke command requires a normal logged-in GUI session: it launches a real AppKit/WebKit process, validates rendered slides and PDF output, and writes private diagnostic artifacts under `.build/qa` before exiting. In a restricted command runner that cannot connect to the Mac GUI session, use **Help → Run Integration Checks…** instead. That command writes its report and sample renderings to `/tmp/SwiftReveal-QA` and leaves the editor open.

The `Examples` directory contains an editable sample and an offline HTML export. To regenerate them, run `swift run SwiftRevealTool generate-examples "$PWD/Examples"` using the same cache environment as the build scripts.

See [PLAN.md](PLAN.md) for scope and architecture, [docs/TESTING.md](docs/TESTING.md) for the acceptance checklist, and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for dependency licensing.

## Interaction troubleshooting

Add Slide and Add Block use regular buttons with popover choices, so insertion is independent of native menu tracking. Background WebKit rendering runs in nonactivating, mouse-ignoring panels excluded from document focus and the Window menu.

If the macOS menu bar does not open while text fields and normal buttons still work, use the toolbar **Diagnostics** button. It saves application/window state and menu-tracking events to `/tmp/SwiftReveal-Diagnostics/menu-state.json` and provides a copy button. The report excludes slide contents, document names and typed text. A machine-specific native-menu issue remains under investigation. The New window/Open and Copy/Paste controls provide access without the menu bar. Diagnostics include menu ownership and structure, plus a **Reconnect menu bar** button that re-registers the current menu with AppKit.

## Current boundaries

PPTX import/export, arbitrary HTML import, collaboration, AI services and free-form drawing are not currently supported. Import custom plots as figures. Layouts preserve readable text and report overflow rather than silently shrinking content.

Local documents and exports stay on your Mac. No account, server or runtime network connection is needed.

## Licence

SwiftReveal is released under the [MIT License](LICENSE). Vendored reveal.js and Mermaid are MIT-licensed; their original notices and bundled dependency notices are retained. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The Azure stacked-slides icon (option A) is installed as the app icon. Alternative concepts remain in `Assets/IconOptions`.
