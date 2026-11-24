# Third-party notices

SwiftReveal includes reveal.js, licensed under the MIT License.

SwiftReveal's original source is also licensed under the MIT License; see LICENSE. The upstream copyright and licence for reveal.js are retained separately below and in the resource bundle.

Vendored upstream release tag: **5.2.1**. The distributed JavaScript banner in that tag identifies itself as 5.2.0. The optional source-map reference was removed because the source map is not distributed with this app. No functional changes were made to the library or stylesheet.

Upstream: https://github.com/hakimel/reveal.js

Source files: `dist/reveal.js`, `dist/reveal.css`, `LICENSE` at tag `5.2.1`.

The complete upstream license is in `Sources/SwiftRevealCore/Resources/reveal-LICENSE`, included in the application resource bundle. HTML exports also embed the MIT license notice.

The example figure is an original illustration with invented values, supplied to demonstrate figure layout. It must not be interpreted as research evidence.

## Mermaid

SwiftReveal includes Mermaid **11.12.0** (MIT), using the self-contained browser bundle vendored by Quarto. The exact original Git blob is `0f033c79e81c5ae6e07b2eb1f1ba13cc31ff94aa` in `quarto-dev/quarto-cli`, at `src/resources/formats/html/mermaid/mermaid.min.js`. The JavaScript artifact is unmodified and retains its original bundled license banners; no Quarto application code is incorporated.

Mermaid upstream: https://github.com/mermaid-js/mermaid/tree/mermaid%4011.12.0

The complete Mermaid licence is retained in `Sources/SwiftRevealCore/Resources/mermaid-LICENSE`. Bundled runtime dependencies include DOMPurify (dual Apache-2.0/MPL-2.0), Chevrotain (Apache-2.0), D3 and D3 Sankey (ISC/BSD), and MIT-licensed rendering/parsing utilities. Full upstream licence and copyright texts are in `mermaid-THIRD-PARTY-NOTICES` in the same resource directory. All notices ship inside the app and are embedded in HTML exports that contain Mermaid blocks. These permissive dependency licences are compatible with SwiftReveal's MIT licence; dependency copyrights and terms remain applicable to their respective code.

Diagram rendering uses no remote service, CDN or external asset. Only flowcharts/graphs are enabled. Output is SVG with a restricted element/attribute allowlist; Mermaid configuration directives and front matter cannot override the fixed security settings.

## PowerPoint export

The offline PowerPoint runtime bundles PptxGenJS 4.0.0 (MIT), JSZip 3.10.1 (MIT option), and their browser dependencies. Complete licences are in `Sources/SwiftRevealCore/Resources/powerpoint-THIRD-PARTY-NOTICES`, shipped with the app. The source, exact dependencies, lockfile and rebuild command are in `packaging/powerpoint`. No server or installed Office application is required for export.
