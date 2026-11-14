# Public release checks

Release: 0.4.0. Date: 14 November 2026.

## Source and examples

- Default tables use generic items, categories and values.
- The default blue palette is named Azure. Unrecognized stored palette names fall back to Azure, preserving readability of older documents without keeping obsolete identifiers in source.
- The tutorial document, HTML export and example chart are regenerated from the current generic source.
- Icon concepts are original review assets; no final production icon has been selected.
- MIT licensing is declared at the repository root and included in the app bundle. The original reveal.js MIT copyright and permission notices remain in its resource bundle and exported HTML.
- Environment files, signing keys, provisioning profiles and logs are ignored by Git.

## Build and validation

- 53 automated tests pass across eight suites.
- Release builds run in a disposable neutral path, rather than embedding the checkout directory in the executable. Release debug symbols are stripped.
- Application property-list validation and strict ad-hoc signature verification are required by the build script.
- Source/assets, remaining Git objects and release app files are scanned for project-specific references, personal checkout identifiers, private-key headers, common access-token formats and credential-bearing URLs. Findings are reported without copying credential values into documentation.
- Pattern scanning reduces risk but cannot prove the absence of every possible secret. Runtime visual checks remain described separately in VALIDATION.md.

## Repository

The public-ready local repository starts with one audited initial commit and a release tag, using a generic project author identity. Old local references, tags, reflogs and unreachable Git objects are removed. No remote is configured and no publishing or pushing is performed as part of this preparation.

Use the current repository for the initial GitHub push. Do not import an older clone, backup, build cache or previous history into the public repository.
