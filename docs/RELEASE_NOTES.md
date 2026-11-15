SwiftReveal 0.5.4 removes the experimental menu bridge responsible for the 0.5.3 startup crash and retains insertion independently of native menu tracking. Add Slide and Add Block use button-driven popovers; offscreen rendering windows are nonactivating panels isolated from menu/focus handling. A Diagnostics button records app/window/menu state without document content. The user confirmed insertion works; the macOS menu-bar issue remains under investigation. Diagnostics now include menu ownership/structure and a reconnect action.

Version 0.5 also adds:

- Independent horizontal and vertical centring for title slides containing no content blocks.
- Editable Mermaid flowchart/DAG blocks with bundled offline rendering to SVG. PDF export waits for diagrams and rejects invalid source instead of exporting an empty block.
- Fenced Markdown code blocks with syntax highlighting, preserved whitespace and indentation, four-space tab stops and readable proportional font scaling.
- An editable Diagrams-and-Code example presentation.

Existing presentations remain compatible. Native preview, navigator thumbnails, HTML export and PDF use the shared renderer. Mermaid and dependency licences are retained alongside the existing reveal.js notices.

Download the `arm64` ZIP for Apple silicon or `x86_64` for Intel. Requires macOS 14 or newer. The app is ad-hoc signed and not Apple-notarized. See README.md for first-launch and installation instructions and docs/VALIDATION.md for test evidence.
