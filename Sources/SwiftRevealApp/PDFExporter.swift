import AppKit
import Foundation
import PDFKit
import WebKit
import SwiftRevealCore

enum PDFExportError: LocalizedError {
    case busy, emptyDeck, timedOut(String), failedPage(Int), couldNotEncode
    var errorDescription: String? {
        switch self {
        case .busy: return "A PDF export is already in progress."
        case .emptyDeck: return "There are no slides to export."
        case .timedOut(let stage): return "PDF export timed out while \(stage). Please try again."
        case .failedPage(let index): return "Could not create a single PDF page for slide \(index + 1)."
        case .couldNotEncode: return "The PDF could not be encoded."
        }
    }
}

/// Captures each slide independently, preserving vector text and exact 16:9 page bounds.
@MainActor final class PDFExporter: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var hostWindow: NSWindow?
    private var navigationCompletion: (@MainActor @Sendable (Result<Void, Error>) -> Void)?
    private var exporting = false

    func export(deck: Deck, to url: URL) async throws {
        guard !exporting else { throw PDFExportError.busy }
        guard !deck.slides.isEmpty else { throw PDFExportError.emptyDeck }
        exporting = true
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 1280, height: 720), configuration: configuration)
        view.navigationDelegate = self
        webView = view
        let host = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 1280, height: 720),
                            styleMask: [.borderless], backing: .buffered, defer: false)
        host.isReleasedWhenClosed = false
        host.contentView = view
        host.orderBack(nil)
        hostWindow = host
        defer {
            navigationCompletion = nil
            view.stopLoading()
            view.navigationDelegate = nil
            host.orderOut(nil)
            host.close()
            hostWindow = nil
            webView = nil
            exporting = false
        }

        let output = PDFDocument()
        output.documentAttributes = [PDFDocumentAttribute.titleAttribute: deck.title,
                                     PDFDocumentAttribute.authorAttribute: deck.author,
                                     PDFDocumentAttribute.creatorAttribute: "SwiftReveal"]
        for index in deck.slides.indices {
            try Task.checkCancellation()
            try await load(HTMLRenderer.singleSlide(deck: deck, slideIndex: index), into: view)
            // Await actual font/image decoding. Offscreen web views may throttle animation frames,
            // so the renderer's optional two-frame promise has a bounded fallback after layout.
            let _: Any? = try await performWithTimeout(stage: "preparing slide \(index + 1)") { finish in
                view.callAsyncJavaScript("""
                await document.fonts.ready;
                await Promise.all(Array.from(document.images).map(async image => {
                  if (!image.complete) await new Promise(resolve => {
                    image.addEventListener('load', resolve, {once:true});
                    image.addEventListener('error', resolve, {once:true});
                  });
                  if (image.decode && image.naturalWidth) await image.decode().catch(() => {});
                }));
                document.documentElement.getBoundingClientRect();
                if (window.swiftRevealReady) await Promise.race([
                  window.swiftRevealReady, new Promise(resolve => setTimeout(resolve, 150))
                ]);
                return true;
                """, arguments: [:], in: nil, in: .page, completionHandler: { result in
                    finish(result.map { Optional($0) })
                })
            }
            let pdfConfiguration = WKPDFConfiguration()
            pdfConfiguration.rect = CGRect(x: 0, y: 0, width: 1280, height: 720)
            let data: Data = try await performWithTimeout(stage: "capturing slide \(index + 1)") { finish in
                view.createPDF(configuration: pdfConfiguration, completionHandler: finish)
            }
            guard let document = PDFDocument(data: data), document.pageCount == 1,
                  let page = document.page(at: 0) else { throw PDFExportError.failedPage(index) }
            output.insert(page, at: output.pageCount)
        }
        try Task.checkCancellation()
        guard let data = output.dataRepresentation() else { throw PDFExportError.couldNotEncode }
        // Atomic write prevents an interrupted export replacing an existing file with a partial PDF.
        try data.write(to: url, options: .atomic)
    }

    private func load(_ html: String, into view: WKWebView) async throws {
        defer { navigationCompletion = nil }
        try await performWithTimeout(stage: "loading a slide") { finish in
            navigationCompletion = finish
            view.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationCompletion?(.success(()))
        navigationCompletion = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationCompletion?(.failure(error))
        navigationCompletion = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationCompletion?(.failure(error))
        navigationCompletion = nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        navigationCompletion?(.failure(PDFExportError.timedOut("rendering a slide")))
        navigationCompletion = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        decisionHandler(scheme == "about" || scheme == nil ? .allow : .cancel)
    }

    private func performWithTimeout<T>(stage: String,
                                       start: (@escaping @MainActor @Sendable (Result<T, Error>) -> Void) -> Void) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let operation = PendingWebOperation(continuation)
            let timeout = DispatchWorkItem { operation.resolve(.failure(PDFExportError.timedOut(stage))) }
            operation.timeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: timeout)
            start { operation.resolve($0) }
        }
    }
}

@MainActor private final class PendingWebOperation<Value> {
    private var continuation: CheckedContinuation<Value, Error>?
    var timeout: DispatchWorkItem?

    init(_ continuation: CheckedContinuation<Value, Error>) { self.continuation = continuation }

    func resolve(_ result: Result<Value, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        timeout = nil
        continuation.resume(with: result)
    }
}
