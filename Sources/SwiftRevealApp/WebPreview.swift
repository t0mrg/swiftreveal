import AppKit
import SwiftUI
import WebKit
import SwiftRevealCore

/// A native host for the deterministic slide renderer. No external navigation is allowed.
struct SlideWebPreview: NSViewRepresentable {
    var deck: Deck
    var slideIndex: Int
    var onWarnings: ([String]) -> Void
    var onSelectBlock: (UUID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "layoutReport")
        configuration.userContentController.add(context.coordinator, name: "selectedBlock")
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onWarnings = onWarnings
        coordinator.onSelectBlock = onSelectBlock
        guard coordinator.deck != deck || coordinator.slideIndex != slideIndex else { return }
        let changedSlide = coordinator.slideIndex != slideIndex
        coordinator.deck = deck
        coordinator.slideIndex = slideIndex
        coordinator.generation += 1
        let generation = coordinator.generation
        coordinator.pendingUpdate?.cancel()
        let html = HTMLRenderer.preview(deck: deck, slideIndex: slideIndex)
        let update = DispatchWorkItem { [weak webView, weak coordinator] in
            guard let webView, let coordinator, coordinator.generation == generation else { return }
            let controller = webView.configuration.userContentController
            controller.removeAllUserScripts()
            controller.addUserScript(WKUserScript(
                source: "window.swiftRevealGeneration = \(generation);",
                injectionTime: .atDocumentStart, forMainFrameOnly: true))
            webView.loadHTMLString(html, baseURL: nil)
        }
        coordinator.pendingUpdate = update
        DispatchQueue.main.asyncAfter(deadline: .now() + (changedSlide ? 0 : 0.15), execute: update)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.pendingUpdate?.cancel()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "layoutReport")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "selectedBlock")
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var deck: Deck?
        var slideIndex = -1
        var generation = 0
        var pendingUpdate: DispatchWorkItem?
        var onWarnings: ([String]) -> Void = { _ in }
        var onSelectBlock: (UUID) -> Void = { _ in }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame else { return }
            if message.name == "layoutReport", let body = message.body as? [String: Any],
               let reportIndex = body["slideIndex"] as? Int,
               let reportGeneration = body["generation"] as? Int,
               reportIndex == slideIndex, reportGeneration == generation,
               let warnings = body["warnings"] as? [String] {
                onWarnings(warnings)
            } else if message.name == "selectedBlock", let value = message.body as? String,
                      let identifier = UUID(uuidString: value),
                      let deck, deck.slides.indices.contains(slideIndex),
                      deck.slides[slideIndex].blocks.contains(where: { $0.id == identifier }) {
                onSelectBlock(identifier)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // loadHTMLString uses about:blank. Images are embedded data resources.
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            decisionHandler(scheme == "about" || scheme == nil ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onWarnings(["Preview could not load: \(error.localizedDescription)"])
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            onWarnings(["The preview process stopped. Edit the slide or select it again to reload."])
            deck = nil
        }
    }
}

/// Owns presentation windows independently of document editors.
@MainActor final class PresentationController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    static let shared = PresentationController()
    private var windows: [NSWindow] = []

    func present(deck: Deck, startIndex: Int) {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "closePresentation")
        configuration.userContentController.addUserScript(WKUserScript(source: """
        document.addEventListener('keydown', function(event) {
          if (event.key === 'Escape') {
            event.preventDefault(); event.stopImmediatePropagation();
            window.webkit.messageHandlers.closePresentation.postMessage('close');
          }
        }, true);
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: deck.effectiveAspectRatio.width, height: deck.effectiveAspectRatio.height), configuration: configuration)
        webView.navigationDelegate = self
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: deck.effectiveAspectRatio.width, height: deck.effectiveAspectRatio.height),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "\(deck.title) — Present · ← → to navigate · Esc to close"
        window.contentView = webView
        window.contentMinSize = NSSize(width: 640, height: 640 / deck.effectiveAspectRatio.ratio)
        window.collectionBehavior = [.fullScreenPrimary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        windows.append(window)
        webView.loadHTMLString(HTMLRenderer.presentation(deck: deck, startIndex: startIndex), baseURL: nil)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "closePresentation", message.frameInfo.isMainFrame else { return }
        message.webView?.window?.performClose(nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme?.lowercased()
        decisionHandler(scheme == "about" || scheme == nil ? .allow : .cancel)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if let webView = window.contentView as? WKWebView {
            webView.stopLoading()
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "closePresentation")
        }
        windows.removeAll { $0 === window }
    }
}
