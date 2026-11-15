# SwiftReveal

A native macOS editor for structured slide presentations. Edit content and select a layout; consistent rules handle margins, alignment, spacing and typography.

## Install

Download the appropriate ZIP from [GitHub Releases](https://github.com/t0mrg/swiftreveal/releases/latest): `arm64` for Apple silicon or `x86_64` for Intel. Unzip it and move **SwiftReveal.app** to Applications.

After the first release and cask have been published, install with Homebrew:

```sh
brew install --cask t0mrg/tap/swiftreveal
```

Requires macOS 14 or newer. The app is ad-hoc signed and is not yet notarized by Apple. If macOS blocks the first launch of this trusted download, attempt to open the app, then use **System Settings → Privacy & Security → Open Anyway**. Homebrew does not disable quarantine automatically.

See [distribution instructions](docs/DISTRIBUTION.md) for publishing releases and updating the cask.

## Run the testing build

Open `dist/SwiftReveal.app`, then choose **New Document** (or **File → New**). New documents start with a single title slide and no content blocks. An editable tutorial deck remains available in `Examples/Getting-Started.swiftreveal`. Save your own copy with **File → Save** (`⌘S`). The app uses `.swiftreveal` files, portable JSON containing the presentation and embedded figures. The example chart and values are illustrative, not real-world data.

Requires macOS 14 or newer. The supplied build is for Apple silicon and is locally ad-hoc signed, not notarized. It is intended for testing on this Mac. Building from source on an Intel Mac produces an Intel build.

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

Select a figure block and import PNG, JPEG, TIFF or PDF. The first page of a PDF is used. Imports are normalized to an embedded PNG with a maximum edge of 4096 pixels, so no external file links can break. Choose **Fit** to retain the whole figure, or crop to fill its frame. Add a caption/source below. Vector source import is rasterized in this release; vector chart authoring is deferred.

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

If the macOS menu bar does not open while text fields and normal buttons still work, use the toolbar **Diagnostics** button. It saves application/window state and menu-tracking events to `/tmp/SwiftReveal-Diagnostics/menu-state.json` and provides a copy button. The report excludes slide contents, document names and typed text. The user confirmed insertion works with the popovers; the macOS menu-bar failure remains under investigation. Diagnostics include menu ownership and structure, plus a **Reconnect menu bar** button that re-registers the current menu with AppKit.

## Current boundaries

This is a first testing release, not a PowerPoint replacement for arbitrary legacy decks. No PPTX import/export, arbitrary HTML import, collaboration, AI service or arbitrary drawing canvas. Custom plots are imported as figures. It does not infer scientific conclusions or alter your text to make it fit.

Local documents and exports stay on your Mac. No account, server or runtime network connection is needed.

## Licence

SwiftReveal is released under the [MIT License](LICENSE). Vendored reveal.js and Mermaid are MIT-licensed; their original notices and bundled dependency notices are retained. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The Azure stacked-slides icon (option A) is installed as the app icon. Alternative concepts remain in `Assets/IconOptions`.
