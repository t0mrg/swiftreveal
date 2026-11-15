# Vendored dependencies

reveal.js, from the upstream release tag **5.2.1**:
- https://github.com/hakimel/reveal.js/blob/5.2.1/dist/reveal.js
- https://github.com/hakimel/reveal.js/blob/5.2.1/dist/reveal.css
- https://github.com/hakimel/reveal.js/blob/5.2.1/LICENSE

The upstream JavaScript artifact's banner identifies itself as 5.2.0. Files were fetched from tag 5.2.1 without functional modifications. The source map reference was removed because the optional map is not shipped. MIT license is included as reveal-LICENSE.

The library and stylesheet are embedded in HTML exports. No CDN or network access is required.


Mermaid **11.12.0**:
- Upstream: https://github.com/mermaid-js/mermaid/tree/mermaid%4011.12.0
- Browser distribution: https://github.com/quarto-dev/quarto-cli/blob/main/src/resources/formats/html/mermaid/mermaid.min.js
- Pinned distribution Git blob: `0f033c79e81c5ae6e07b2eb1f1ba13cc31ff94aa`

The full self-contained distribution is unmodified. Its embedded version marker identifies Mermaid 11.12.0. The bundle's original third-party licence banners are retained. Full Mermaid MIT terms are in `mermaid-LICENSE`; additional bundled dependency copyright/licence texts are in `mermaid-THIRD-PARTY-NOTICES`. Both are also embedded in diagram-containing HTML exports.
