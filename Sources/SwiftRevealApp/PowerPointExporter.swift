import AppKit
import Foundation
import WebKit
import SwiftRevealCore

enum PowerPointExportError: LocalizedError {
    case busy, emptyDeck, timedOut(String), couldNotEncode, javaScript(String)
    var errorDescription: String? {
        switch self {
        case .busy: return "A PowerPoint export is already in progress."
        case .emptyDeck: return "There are no slides to export."
        case .timedOut(let stage): return "PowerPoint export timed out while \(stage). Please try again."
        case .couldNotEncode: return "The PowerPoint could not be encoded."
        case .javaScript(let message): return message
        }
    }
}

/// Measures the shared renderer and writes native editable OOXML objects offline.
@MainActor final class PowerPointExporter: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var hostWindow: RenderHostPanel?
    private var navigationCompletion: (@MainActor @Sendable (Result<Void, Error>) -> Void)?
    private var exporting = false

    func export(deck: Deck, to url: URL) async throws -> [String] {
        guard !exporting else { throw PowerPointExportError.busy }
        guard !deck.slides.isEmpty else { throw PowerPointExportError.emptyDeck }
        exporting = true
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: deck.effectiveAspectRatio.width, height: deck.effectiveAspectRatio.height), configuration: configuration)
        view.navigationDelegate = self
        webView = view
        let host = RenderHostPanel(content: view)
        host.prepareForRendering()
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

        var slides: [[String: Any]] = []
        var masters: [[String: Any]] = []
        var warnings: [String] = []
        // Measure all eight starter layouts, even if the deck does not use them.
        let templates = Deck(title: deck.title, author: deck.author, footer: deck.footer,
                             theme: deck.theme, slides: SlideLayout.allCases.map(Slide.starter),
                             customCSS: deck.customCSS, aspectRatio: deck.aspectRatio)
        for index in templates.slides.indices {
            try Task.checkCancellation()
            let snapshot = try await capture(deck: templates, index: index, view: view)
            masters.append(["layout": templates.slides[index].layout.rawValue,
                            "label": templates.slides[index].layout.label, "snapshot": snapshot])
        }
        for index in deck.slides.indices {
            try Task.checkCancellation()
            let snapshot = try await capture(deck: deck, index: index, view: view)
            let issues = snapshot["warnings"] as? [String] ?? []
            warnings += issues.map { "Slide \(index + 1): " + $0 }
            slides.append(["layout": deck.slides[index].layout.rawValue,
                           "notes": deck.slides[index].notes, "snapshot": snapshot])
        }
        let palette = deck.theme.palette
        let colors = ["dk1": palette.ink, "lt1": palette.surface, "dk2": palette.deep, "lt2": palette.tint,
                      "accent1": palette.accent, "accent2": palette.deep, "accent3": palette.cover2,
                      "accent4": palette.secondary, "accent5": palette.muted, "accent6": palette.rule,
                      "hlink": palette.accent, "folHlink": palette.deep].mapValues { String($0.dropFirst()) }
        let payload: [String: Any] = ["title": deck.title, "author": deck.author, "footer": deck.footer, "colors": colors,
            "width": deck.effectiveAspectRatio.width, "height": deck.effectiveAspectRatio.height,
            "masters": masters, "slides": slides]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        let base64: Any? = try await performWithTimeout(stage: "encoding the PowerPoint file", seconds: 120) { finish in
            view.callAsyncJavaScript("return await window.swiftRevealPowerPoint.write(payload);",
                                     arguments: ["payload": json], in: nil, in: .page) { result in
                finish(result.map { Optional($0) })
            }
        }
        try Task.checkCancellation()
        guard let encoded = base64 as? String, let data = Data(base64Encoded: encoded),
              data.starts(with: [0x50, 0x4b, 0x03, 0x04]) else { throw PowerPointExportError.couldNotEncode }
        try data.write(to: url, options: .atomic)
        return Array(Set(warnings)).sorted()
    }

    private func capture(deck: Deck, index: Int, view: WKWebView) async throws -> [String: Any] {
        try await load(HTMLRenderer.powerPointSlide(deck: deck, slideIndex: index), into: view)
        let result: Any? = try await performWithTimeout(stage: "measuring slide \(index + 1)") { finish in
            view.callAsyncJavaScript("return await window.swiftRevealPowerPoint.capture();",
                                     arguments: [:], in: nil, in: .page) { result in
                finish(result.map { Optional($0) })
            }
        }
        guard let json = result as? String,
              let snapshot = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            throw PowerPointExportError.couldNotEncode
        }
        return snapshot
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
        navigationCompletion?(.failure(PowerPointExportError.timedOut("rendering a slide")))
        navigationCompletion = nil
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        decisionHandler(scheme == "about" || scheme == nil ? .allow : .cancel)
    }

    private func performWithTimeout<T>(stage: String, seconds: TimeInterval = 30,
                                       start: (@escaping @MainActor @Sendable (Result<T, Error>) -> Void) -> Void) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let operation = PendingPowerPointOperation(continuation)
            let timeout = DispatchWorkItem { operation.resolve(.failure(PowerPointExportError.timedOut(stage))) }
            operation.timeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: timeout)
            start { result in
                operation.resolve(result.mapError { error in
                    let info = (error as NSError).userInfo
                    if let message = info["WKJavaScriptExceptionMessage"] as? String {
                        return PowerPointExportError.javaScript(message)
                    }
                    return error
                })
            }
        }
    }
}

@MainActor private final class PendingPowerPointOperation<Value> {
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
