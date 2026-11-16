# SwiftReveal validation

## 0.8.0 testing build — raster and storage efficiency

The SVG checkpoint was already committed as 388b4fd. Raster imports now use bounded ImageIO decoding with resolution presets and correct EXIF orientation, preserve unchanged JPEG/PNG bytes, retain transparency and bypass SVG. The Optimize panel analyzes a captured deck on a cancellable worker, presents before/after estimates, guards against stale source edits and applies changes through one document-binding update. Opaque PNG conversion is opt-in; the Original preset skips all image changes. Native regression tests include format preservation, dimensions, rotation pixels/metadata, transparency, size/no-upscale policies, image-quality error bounds and complete-deck content/style preservation.

PresentationFile reads old plain JSON and writes a versioned, asset-deduplicated LZFSE container only when it saves at least 5% and 1 KiB. Integrity, version, payload-length, bounded-decompression and independent asset checks are tested. Small decks remain JSON. The FileDocument path uses this storage helper, the presentation UTI conforms to public.data, and Editable JSON export provides an older-version/source-inspection copy. A storage revision marks explicit lossless optimization dirty even if image bytes remain identical. Export and clipboard model formats are otherwise unchanged.

All 108 Swift tests across 17 suites and four packaging tests pass. Generated image tests measured 995,880→329,325 bytes for optional photo-like PNG conversion and 382,284→269,675 bytes for JPEG recompression. The included Getting Started generation measured 168,620→46,571 bytes (72.4%) using lossless storage alone; decoding preserved the entire deck. A unique high-entropy asset fixture saved about 24%, and repeated-image fixtures saved over 80%. These are fixture measurements rather than universal compression ratios.

The rebuilt Apple silicon app passes strict ad-hoc signature verification. Native multiwindow/save-panel/autosave, optimization Apply/Undo and exported visual-quality checks remain user acceptance items because GUI inspection is restricted in this session. Examples include an efficient file for testing native opening. No release, tag, push or Homebrew update is included.

## 0.7.0 testing build — SVG figures and backgrounds

SVG import is enabled for figure and background pickers. A shared static-SVG validator regenerates safe, self-contained XML while retaining paths, text, local styles, gradients, clipping, masks, filters, internal references and embedded PNG/JPEG content. Known external-only W3C SVG DTDs are removed without resolution; scripts, external resources, entity declarations and unsupported active/style constructs are rejected. SVG is revalidated at the rendering boundary for manually edited documents and embedded as an isolated image data URL.

The native importer preserves sanitized SVG bytes/MIME, normalizes raster/PDF imports as before, and uses WebKit for inspector SVG previews without enabling page JavaScript. Existing fit/crop, background overlays, document serialization and slide-transfer payloads apply unchanged. Original illustrative SVG figure/background files and an SVG-Images sample deck are generated with the other examples.

All 86 application tests and three packaging tests pass. Tests cover plotting-tool patterns, CSS/CDATA, namespaces, dimensions, complexity and hostile input, as well as rendering, persistence, duplication, transfer and raster compatibility. The rebuilt Apple silicon app passes strict ad-hoc signature verification. Native integration checks were extended for file import, actual WebKit decoding, clipping/gradient pixels, overlays, and raster-XObject detection in a purely vector PDF fixture. Those GUI/PDF runtime checks have not run in the restricted session; complex PDF effects and font substitutions still require representative user-file testing.

Raster compression/asset deduplication was assessed but not implemented in this feature. No release, tag, push or Homebrew update has been authorized for 0.7.0.

## 0.6.0 — slide transfer and label layout

The previous checkpoint is commit fefe04d. The new work adds explicit New window/Open controls to the document-based app, navigator multiselection, standard navigator Copy/Paste handling, dedicated slide commands/buttons and a versioned slide-only clipboard payload. Paste captures the receiving window/anchor, inserts above the earliest selected target in source order, retains local settings and embedded bytes, and keeps destination theme/CSS/metadata unchanged. Each paste creates fresh slide/block IDs. Async paste is cancelled on receiving editor closure; context-menu and keyboard/button paste use the same multi-selection anchor policy.

Mermaid's stripped generated stylesheet contained its node-label centre-anchor rule; preserving that SVG anchor fixes the concrete rightward-label shift. Diagram measurement and final SVG now share font family/size and base typography. Added native geometry checks cover Process, multiline labels, rectangles/diamond/stadium, dark themes, custom slide fonts, compound scaling and arrowheads.

All 73 application tests and three packaging tests pass. The complete app compiles and passes strict ad-hoc signature verification. Source-level review covered clipboard representations, window routing, selection and text-command isolation. The GUI-restricted runner has not verified native multiwindow/clipboard, Undo/Redo or rendered label geometry/PDF. The user subsequently confirmed that the testing build works and authorized publication, a new GitHub release and the Homebrew cask update. TESTING.md retains the detailed regression checklist; individual geometry-harness assertions are not implied to have run in the restricted runner.

## 0.5.4 startup crash recovery

Crash reports for the experimental 0.5.3 build identify an AppKit assertion in `NSMenuItem.setSubmenu`, called by `MenuMirror.refresh`. The menu workaround attempted to attach an already-owned submenu to another item. The entire experimental native-menu bridge and its startup hook were removed; 0.5.4 restores the standard SwiftUI document menus while retaining working insertion popovers and diagnostics. This is separate from the earlier machine-specific failure to open menus. The same app works on another Mac; local preferences contain only ordinary open/color-panel settings and no obvious menu override. No user preferences or documents were reset. The user confirmed 0.5.4 opens, edits and adds slides normally. All 65 application tests and three packaging tests pass; the recovery app passes strict ad-hoc signature verification and its executable contains no native-menu bridge symbols. The earlier machine-specific menu-bar failure remains unresolved.

## 0.5.1 interaction investigation

The user reports that Add Slide, Add Block and the standard macOS menus do not open. Text fields and Deck settings still work, Finder's menus work, and switching away/back does not restore SwiftReveal menus. These observations point to app-specific menu presentation/tracking rather than failed insertion mutations or a completely blocked main thread. The user confirmed Add Slide/Add Block work in 0.5.1, then clarified that the macOS menu bar still does not work. The original report that all menus worked was corrected. The log shows normal application activation, a key/main document window and no modal window; no menu-tracking events are received. This rules out hidden app-modal dialogs or render-host focus as the observed explanation in that snapshot. Re-registering the existing menu did not resolve the failure. The user subsequently confirmed that the same app works on another Mac, making local machine/user-state or an OS-version-specific interaction more likely. Targeted preference inspection found only open/color-panel UI state, no menu-related overrides, and no saved-state directory in the standard app locations. No preferences were reset. The exact remaining cause is under investigation.

Add Slide and Add Block now use ordinary buttons with popover choices. Rendering hosts are explicit nonactivating NSPanel subclasses, cannot become key/main, ignore mouse input and are excluded from the Window menu. Reused thumbnail hosts are no longer reordered per request. The integration browser is closed through defer on failures as well as success. A toolbar diagnostics sheet records activation, modal/key/main window state and menu-tracking events without document content.

All 65 application tests and three packaging tests pass, including compilation of the native UI. The user confirmed insertion works in 0.5.1; menu-bar failure remains. Automated UI observation and full WebKit/PDF runtime verification remain unavailable: screen capture is denied, process inspection and system logs are blocked by the command runner, and native launch/smoke attempts cannot connect to the GUI session. Version 0.5.2 adds menu structure/owner diagnostics and a button to re-register the existing SwiftUI main menu with AppKit without replacing its actions or delegates.

## 0.5.0 diagrams, title alignment and code

All 65 application tests pass. Fenced code covers 17 highlighted languages, whitespace and literal markup; diagram tests cover offline embedding, security policy hashes, sanitization guards, title alignment conditions and font styles. Optional title alignment fields and Mermaid source survive saving and duplication. The complete app compiles and includes an editable Diagrams-and-Code example. Native SVG/PDF rendering remains to be verified in the logged-in Mac session.

## Icon and distribution packaging

Option A (Azure stacked slides) is installed in the app bundle. macOS successfully decoded the ICNS file for inspection. All 53 application tests and three packaging tests pass. Apple silicon and Intel release builds compile and pass strict ad-hoc signature verification. Both ZIPs contain the expected architecture, version and icon; their checksums match SHA256SUMS and the generated cask. Both archives pass the source-reference and credential-pattern scans. Homebrew's installed cask loader successfully parses the generated cask; no installation was performed.

GitHub Actions workflows have been added for tests and releases. Their YAML parses locally, but remote execution, asset downloads and Homebrew installation await publication. Publishing from this session is blocked: shell GitHub DNS resolution fails, and the connected GitHub integration rejects writes to the destination repository with HTTP 403. No public release or tap update is claimed.

## 0.4.0 public release preparation

53 automated tests pass. The default palette is Azure, the examples are generic, the project has an MIT licence, and release packaging uses a neutral disposable build path. See RELEASE_CHECKS.md for source, history and binary audit scope. Native visual testing remains pending as described below.

## 0.3.0 typography, safe rich text and CSS themes

51 automated tests pass across eight suites. The native application compiles with slide/block font-scale controls, the CSS editor and the reusable theme library. Tests cover backward-compatible document loading; scale bounds, persistence and compound scopes; mixed Markdown/HTML sanitization and attack payloads; theme portability; safe CSS embedding; deterministic output; and exact content-security-policy hashes for every trusted script.

The renderer now measures unscaled computed font sizes before applying slide × block factors, so custom CSS font sizes also scale without repeated inheritance multiplication. The opt-in in-app integration suite checks actual computed sizes, mixed formatting, custom CSS and script suppression. Those WebKit runtime checks and native theme save/load interaction remain pending under the GUI restrictions recorded below; they are not implied by the unit-test passes.

The updated application is rebuilt and ad-hoc signature verification is performed by the build script.

## 0.2.0 appearance update

The update adds nine shared themes, per-block and table-header colour overrides, embedded slide background images, an empty title-only new-document default, and a cached navigator thumbnail renderer shared with the production slide renderer. Version 1 documents without appearance fields remain compatible.

27 automated tests pass. The complete native application compiles with the new controls and thumbnail service. The in-app integration suite now checks computed colours, thumbnail invalidation and image backgrounds as well as the existing PDF checks. Runtime visual checks of these additions remain pending under the host GUI restrictions described below.

The release app is rebuilt and ad-hoc signature verification is performed by the build script. No system permissions or settings are changed.

## Original release evidence

Date: 14 November 2026. Host: Apple silicon, macOS 26.6.2, Swift 6.3.3, Command Line Tools SDK. The app deployment target is macOS 14. Earlier supported OS versions have not been exercised.

## Passed

- Release build compiled and linked the complete native app.
- `codesign --verify --deep --strict` accepted the ad-hoc signed application bundle.
- Application property list validated with `plutil`.
- 16 automated Swift Testing tests passed, covering document serialization and schema rejection, embedded bytes, duplicate identities, table parsing, all layout starter models, text escaping, image MIME restrictions, full dependency license in HTML, offline resource embedding and content preservation across layouts.
- App launched through the normal Mac application launcher.
- Created a new document through the native **New Document** button.
- Inspected the live editor's accessibility tree: all eight sample slides, title/subtitle fields, block controls, layouts, notes and export/presentation toolbar are present. WebKit displayed the first slide's expected title, callout, footer and text. No overflow warning was present for that slide.
- Generated an editable sample document and a self-contained HTML example through the headless core utility.

## Not verified in this session

- Full visual inspection, native editing/save/reopen/undo interaction, PDF runtime output and all-slide overflow smoke checks remain to be exercised.
- A direct command-runner launch of the GUI smoke harness aborted in Apple's application-registration code before reaching the app, because that runner cannot register with the GUI session. The app itself launched normally through the native launcher.
- Further native computer-use inspection was blocked by the Mac's screen-capture permission. No permission or system setting was changed.
- The browser tool disallowed a local `file:` URL, so it could not inspect the exported sample. No alternate route was used to bypass that restriction.

The app includes **Help → Run Integration Checks…** so the complete WebKit/PDF suite can run inside the normally launched application. It writes JSON results, every sample slide as a PNG, the editable sample, exported HTML and PDF into `/tmp/SwiftReveal-QA`. Review those results along with the manual checklist in TESTING.md before relying on exports for a real talk.

## Distribution

The app is locally ad-hoc signed. It is not Developer ID signed or notarized and has not been tested on another Mac. An Apple silicon ZIP is produced by the build script. The source tree has an audited local Git history and a configured GitHub origin. Distribution scripts and GitHub Actions prepare both architectures and the Homebrew cask; see DISTRIBUTION.md.
