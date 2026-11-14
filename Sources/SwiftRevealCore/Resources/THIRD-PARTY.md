# Vendored dependencies

reveal.js, from the upstream release tag **5.2.1**:
- https://github.com/hakimel/reveal.js/blob/5.2.1/dist/reveal.js
- https://github.com/hakimel/reveal.js/blob/5.2.1/dist/reveal.css
- https://github.com/hakimel/reveal.js/blob/5.2.1/LICENSE

The upstream JavaScript artifact's banner identifies itself as 5.2.0. Files were fetched from tag 5.2.1 without functional modifications. The source map reference was removed because the optional map is not shipped. MIT license is included as reveal-LICENSE.

The library and stylesheet are embedded in HTML exports. No CDN or network access is required.
