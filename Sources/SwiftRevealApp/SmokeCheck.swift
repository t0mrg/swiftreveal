import AppKit
import Darwin
import Foundation
import PDFKit
import WebKit
import SwiftRevealCore

/// An opt-in integration harness. Nothing runs during a normal app launch.
/// Usage: SwiftReveal --smoke-test /absolute/output/directory
@MainActor enum SmokeCheck {
    private static var attempted = false
    private static var running = false

    static func runIfRequested() async -> Bool {
        guard !attempted, let flag = CommandLine.arguments.firstIndex(of: "--smoke-test") else { return false }
        attempted = true
        let path = CommandLine.arguments.indices.contains(flag + 1)
            ? CommandLine.arguments[flag + 1] : FileManager.default.currentDirectoryPath + "/.build/qa"
        return await run(output: URL(fileURLWithPath: path, isDirectory: true), exitWhenFinished: true)
    }

    static func runInteractive() async {
        guard !running else { return }
        let output = URL(fileURLWithPath: "/tmp/SwiftReveal-QA", isDirectory: true)
        let passed = await run(output: output, exitWhenFinished: false)
        let alert = NSAlert()
        alert.messageText = passed ? "Integration checks passed" : "Integration checks found a problem"
        alert.informativeText = "Results and rendered sample slides: " + output.path + "/smoke-results.json"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func run(output: URL, exitWhenFinished: Bool) async -> Bool {
        guard !running else { return false }
        running = true
        defer { running = false }
        var checks: [[String: Any]] = []
        var failures: [String] = []
        func record(_ name: String, _ passed: Bool, _ detail: String = "") {
            checks.append(["name": name, "passed": passed, "detail": detail])
            if !passed { failures.append(name + (detail.isEmpty ? "" : ": " + detail)) }
        }
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let deck = Deck.sample
            let encoded = try deck.encoded()
            try encoded.write(to: output.appendingPathComponent("Sample.swiftreveal"), options: .atomic)
            record("Sample document round trip", try Deck.decode(encoded) == deck)
            let html = HTMLRenderer.export(deck: deck)
            try html.write(to: output.appendingPathComponent("Sample.html"), atomically: true, encoding: .utf8)
            record("Offline reveal.js embedded", html.contains("new Reveal(") && html.contains("class=\"reveal\""))

            let browser = SmokeBrowser()
            for index in deck.slides.indices {
                let report = try await browser.render(HTMLRenderer.singleSlide(deck: deck, slideIndex: index))
                let warnings = report["warnings"] as? [String] ?? ["No layout warning report received"]
                let errors = report["errors"] as? [String] ?? []
                record("Slide \(index + 1) JavaScript", errors.isEmpty, errors.joined(separator: "; "))
                record("Slide \(index + 1) fits", warnings.isEmpty, warnings.joined(separator: "; "))
                let titles = report["titles"] as? [String] ?? []
                record("Slide \(index + 1) content", titles.contains(deck.slides[index].title))
                let size = report["size"] as? [Double] ?? []
                record("Slide \(index + 1) size", size == [1280, 720], "\(size)")
                try await browser.snapshot(to: output.appendingPathComponent(String(format: "slide-%02d.png", index + 1)))
            }

            // Check the live preview path separately from the unscaled PDF renderer.
            let previewReport = try await browser.render(HTMLRenderer.preview(deck: deck, slideIndex: 0))
            record("Preview ready", (previewReport["titles"] as? [String])?.first == deck.slides[0].title)

            // Exercise appearance with actual computed styles, not only markup strings.
            for theme in DeckTheme.allCases {
                var themed = Deck.blank
                themed.theme = theme
                themed.slides[0].layout = .table
                _ = try await browser.render(HTMLRenderer.singleSlide(deck: themed, slideIndex: 0))
                let actual = try await browser.run("return getComputedStyle(document.querySelector('.sr-slide')).backgroundColor;")
                let hex = UInt32(theme.palette.surface.dropFirst(), radix: 16) ?? 0
                let expected = "rgb(\((hex >> 16) & 255), \((hex >> 8) & 255), \(hex & 255))"
                record("Theme \(theme.label) rendered surface", actual as? String == expected)
            }
            var coloured = Deck(slides: [Slide(layout: .table, title: "Colour overrides", blocks: [ContentBlock(kind: .table,
                style: BlockStyle(background: "#EEEEDD", foreground: "#112233", headerBackground: "#334455", headerForeground: "#FFCCAA"))])])
            _ = try await browser.render(HTMLRenderer.singleSlide(deck: coloured, slideIndex: 0))
            let colours = try await browser.run("return [getComputedStyle(document.querySelector('th')).color, getComputedStyle(document.querySelector('th')).backgroundColor, getComputedStyle(document.querySelector('td')).color];")
            record("Table header overrides body text colour", colours as? [String] == ["rgb(255, 204, 170)", "rgb(51, 68, 85)", "rgb(17, 34, 51)"])
            let firstThumbnail = await ThumbnailRenderer.shared.image(html: HTMLRenderer.singleSlide(deck: coloured, slideIndex: 0))
            coloured.theme = .midnight
            let secondThumbnail = await ThumbnailRenderer.shared.image(html: HTMLRenderer.singleSlide(deck: coloured, slideIndex: 0))
            record("Navigator renders thumbnails", firstThumbnail != nil && secondThumbnail != nil)
            record("Navigator changes with theme", firstThumbnail?.tiffRepresentation != secondThumbnail?.tiffRepresentation)
            if let data = deck.slides.compactMap({ $0.blocks.first(where: { $0.imageData != nil })?.imageData }).first {
                coloured.slides[0].background = SlideBackground(imageData: data, overlayColor: "#000000", overlayOpacity: 0.4)
                let backgroundReport = try await browser.render(HTMLRenderer.singleSlide(deck: coloured, slideIndex: 0))
                record("Background image decodes", backgroundReport["imageCount"] as? Int == 1)
                let backgroundLoaded = try await browser.run("return document.querySelector('.sr-background-image').naturalWidth > 0;")
                record("Background image ready", backgroundLoaded as? Bool == true)
            }

            let typography = Deck(slides: [Slide(layout: .twoColumns, kicker: "Kicker", title: "Scaled title", subtitle: "Subtitle", blocks: [
                ContentBlock(kind: .text, heading: "Scaled heading", body: "**Bold <em>mixed</em>** and H<sub>2</sub>O<script>window.smokeInjection=true</script>", caption: "Caption", fontScale: 0.5),
                ContentBlock(kind: .table, fontScale: 1.5)
            ], fontScale: 1.2)], customCSS: ".sr-copy { font-size:20px; } .sr-slide .sr-heading { font-size:30px; } td { font-size:16px; }")
            let typographyReport = try await browser.render(HTMLRenderer.singleSlide(deck: typography, slideIndex: 0))
            record("Rich HTML does not execute", typographyReport["injected"] as? Bool == false)
            let fontChecks = try await browser.run("""
                const blocks=Array.from(document.querySelectorAll('[data-block-id]'));
                const size=e=>parseFloat(getComputedStyle(e).fontSize);
                return [size(document.querySelector('.sr-header h1')),size(document.querySelector('.sr-footer')),
                  size(blocks[0].querySelector('.sr-heading')),size(blocks[0].querySelector('.sr-copy')),
                  size(blocks[0].querySelector('.sr-caption')),size(blocks[1].querySelector('td'))];
                """)
            let actualSizes = fontChecks as? [Double] ?? []
            let expectedSizes: [Double] = [46.8,15.6,18,12,9.6,28.8]
            record("Slide and block scaling includes custom CSS", actualSizes.count == expectedSizes.count && zip(actualSizes,expectedSizes).allSatisfy { abs($0-$1) < 0.1 }, "\(actualSizes)")
            let mixedHTML = try await browser.run("return document.querySelector('.sr-copy strong em')?.textContent === 'mixed';")
            record("Markdown wraps safe HTML", mixedHTML as? Bool == true)
            let cssOverride = try await browser.run("return getComputedStyle(document.querySelector('.sr-copy')).fontSize;")
            record("Edited deck CSS is applied", cssOverride as? String == "12px")

            let malicious = "</script><script>window.smokeInjection=true</script><img src=https://example.invalid/tracker>"
            var unsafe = Deck(title: malicious, slides: [Slide(title: malicious, subtitle: malicious, blocks: [ContentBlock(kind: .text, heading: malicious, body: malicious, caption: malicious)])])
            unsafe.author = malicious; unsafe.footer = malicious
            let safeReport = try await browser.render(HTMLRenderer.singleSlide(deck: unsafe, slideIndex: 0))
            record("User HTML is inert text", safeReport["injected"] as? Bool == false && safeReport["imageCount"] as? Int == 0)
            record("Unsafe text survives document round trip", try Deck.decode(unsafe.encoded()) == unsafe)

            let long = Deck(slides: [Slide(title: "Overflow detection", blocks: [ContentBlock(kind: .text, body: Array(repeating: "A deliberately oversized paragraph to verify that overflow is reported.", count: 100).joined(separator: "\n"))])])
            let longReport = try await browser.render(HTMLRenderer.singleSlide(deck: long, slideIndex: 0))
            record("Oversized content is reported", !(longReport["warnings"] as? [String] ?? []).isEmpty)

            let presentation = try await browser.render(HTMLRenderer.presentation(deck: deck, startIndex: 0))
            record("Presentation JavaScript", (presentation["errors"] as? [String] ?? []).isEmpty)
            let navigation = try await browser.run("""
                window.swiftRevealDeck.slide(1);
                return window.swiftRevealDeck.getIndices().h;
                """)
            record("Presentation navigation", navigation as? Int == min(1, deck.slides.count - 1))

            let pdfURL = output.appendingPathComponent("Sample.pdf")
            try await PDFExporter().export(deck: deck, to: pdfURL)
            if let pdf = PDFDocument(url: pdfURL) {
                record("PDF page count", pdf.pageCount == deck.slides.count, "\(pdf.pageCount) pages")
                for index in 0..<pdf.pageCount {
                    guard let page = pdf.page(at: index) else { record("PDF page \(index + 1)", false); continue }
                    let bounds = page.bounds(for: .mediaBox)
                    record("PDF page \(index + 1) dimensions", abs(bounds.width - 1280) < 0.1 && abs(bounds.height - 720) < 0.1, "\(bounds.size)")
                    if deck.slides.indices.contains(index) {
                        let text = page.string ?? ""
                        let titleWords = deck.slides[index].title.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                        record("PDF page \(index + 1) searchable title", titleWords.allSatisfy { text.contains($0) })
                    }
                }
            } else { record("PDF opens", false) }
            browser.close()
        } catch {
            record("Integration harness completed", false, error.localizedDescription)
        }
        let result: [String: Any] = ["passed": failures.isEmpty, "checks": checks, "failures": failures,
                                     "date": ISO8601DateFormatter().string(from: Date()),
                                     "platform": ProcessInfo.processInfo.operatingSystemVersionString]
        do {
            let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: output.appendingPathComponent("smoke-results.json"), options: .atomic)
        } catch { failures.append("Could not write smoke report: \(error.localizedDescription)") }
        let summary = "SwiftReveal smoke test: \(checks.count) checks, \(failures.count) failures. Report: \(output.path)/smoke-results.json\n" + failures.joined(separator: "\n") + "\n"
        FileHandle.standardOutput.write(Data(summary.utf8))
        if exitWhenFinished { Darwin.exit(failures.isEmpty ? 0 : 1) }
        return failures.isEmpty
    }
}

@MainActor private final class SmokeBrowser: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let window: NSWindow
    private var navigation: ((Result<Void, Error>) -> Void)?

    override init() {
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: """
            window.smokeErrors=[];
            window.addEventListener('error',e=>window.smokeErrors.push(e.message));
            window.addEventListener('unhandledrejection',e=>window.smokeErrors.push(String(e.reason)));
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720), configuration: config)
        window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1280, height: 720), styleMask: [.borderless], backing: .buffered, defer: false)
        super.init()
        webView.navigationDelegate = self
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.orderBack(nil)
    }

    func render(_ html: String) async throws -> [String: Any] {
        try await timed { finish in
            self.navigation = finish
            self.webView.loadHTMLString(html, baseURL: nil)
        }
        let result = try await run("""
            if (window.swiftRevealReady) await window.swiftRevealReady;
            if (window.swiftRevealDeck) {
              const deck=window.swiftRevealDeck;
              if (!deck.isReady()) await new Promise(resolve=>deck.on('ready',resolve));
            }
            const report=window.swiftRevealReport ? window.swiftRevealReport() : {warnings:['Renderer report missing']};
            const slide=document.querySelector('.sr-slide');
            return {...report,errors:window.smokeErrors || [],titles:Array.from(document.querySelectorAll('.sr-slide h1')).map(x=>x.textContent),
              size:slide?[slide.offsetWidth,slide.offsetHeight]:[],injected:window.smokeInjection===true,imageCount:document.images.length};
            """)
        guard let report = result as? [String: Any] else { throw SmokeError.invalidReport }
        return report
    }

    func run(_ script: String) async throws -> Any {
        try await timed { finish in
            self.webView.callAsyncJavaScript(script, arguments: [:], in: nil, in: .page) { result in finish(result) }
        }
    }

    func snapshot(to url: URL) async throws {
        let image: NSImage = try await timed { finish in
            let config = WKSnapshotConfiguration(); config.rect = NSRect(x: 0, y: 0, width: 1280, height: 720)
            self.webView.takeSnapshot(with: config) { image, error in
                if let error { finish(.failure(error)) }
                else if let image { finish(.success(image)) }
                else { finish(.failure(SmokeError.snapshot)) }
            }
        }
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { throw SmokeError.snapshot }
        try png.write(to: url, options: .atomic)
    }

    func close() {
        navigation = nil; webView.stopLoading(); webView.navigationDelegate = nil
        window.orderOut(nil); window.close()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { self.navigation?(.success(())); self.navigation = nil }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { self.navigation?(.failure(error)); self.navigation = nil }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { self.navigation?(.failure(error)); self.navigation = nil }

    private func timed<T>(_ start: (@escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let pending = SmokePending(continuation)
            let timer = DispatchWorkItem { pending.finish(.failure(SmokeError.timeout)) }
            pending.timer = timer
            DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: timer)
            start { pending.finish($0) }
        }
    }
}

@MainActor private final class SmokePending<T> {
    var continuation: CheckedContinuation<T, Error>?
    var timer: DispatchWorkItem?
    init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }
    func finish(_ result: Result<T, Error>) {
        guard let continuation else { return }
        self.continuation = nil; timer?.cancel(); timer = nil; continuation.resume(with: result)
    }
}

private enum SmokeError: LocalizedError {
    case invalidReport, timeout, snapshot
    var errorDescription: String? {
        switch self {
        case .invalidReport: return "The renderer did not return a valid integration report."
        case .timeout: return "A WebKit integration operation timed out."
        case .snapshot: return "Could not capture a slide snapshot."
        }
    }
}
