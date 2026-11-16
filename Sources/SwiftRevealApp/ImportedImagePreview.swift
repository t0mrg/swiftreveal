import AppKit
import SwiftUI
import WebKit
import SwiftRevealCore

/// Preserve SVG source in the document; inspector previews use the same validated
/// image URL as slides instead of converting the document's image into a bitmap.
struct ImportedImagePreview: View {
    let data: Data
    let mime: String

    var body: some View {
        Group {
            if mime == "image/svg+xml", let url = EmbeddedImage.dataURL(data: data, mime: mime) {
                SVGInspectorPreview(imageURL: url)
            } else if mime != "image/svg+xml", let image = NSImage(data: data), image.isValid {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Label("Image preview unavailable", systemImage: "photo")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(mime == "image/svg+xml" ? "Embedded SVG image preview" : "Embedded image preview")
    }
}

private struct SVGInspectorPreview: NSViewRepresentable {
    let imageURL: String
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsLinkPreview = false
        view.allowsBackForwardNavigationGestures = false
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        guard context.coordinator.imageURL != imageURL else { return }
        context.coordinator.imageURL = imageURL
        view.loadHTMLString("""
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; img-src data:; style-src 'unsafe-inline'; connect-src 'none'; object-src 'none'; base-uri 'none'">
        <style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:transparent}img{display:block;width:100%;height:100%;object-fit:contain}</style>
        </head><body><img alt="SVG preview" src="\(imageURL)"></body></html>
        """, baseURL: nil)
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
    }

    @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
        var imageURL: String?
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let scheme = action.request.url?.scheme?.lowercased()
            decisionHandler(scheme == "about" || scheme == nil ? .allow : .cancel)
        }
    }
}
