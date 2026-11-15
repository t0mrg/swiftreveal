# SwiftReveal validation

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
