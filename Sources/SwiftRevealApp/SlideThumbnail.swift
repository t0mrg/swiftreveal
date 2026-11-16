import AppKit
import CryptoKit
import SwiftUI
import WebKit
import SwiftRevealCore

/// The navigator uses the production renderer, so themes, backgrounds and local
/// block colours cannot drift away from the main preview.
struct SlideThumbnail: View {
    let deck: Deck
    let index: Int
    @State private var image: NSImage?

    private var identity: ThumbnailIdentity {
        ThumbnailIdentity(slide: deck.slides[index], theme: deck.theme, footer: deck.footer, number: index, count: deck.slides.count, customCSS: deck.customCSS, aspectRatio: deck.effectiveAspectRatio)
    }
    var body: some View {
        ZStack {
            let palette = deck.theme.palette
            Rectangle().fill(Color(hex: deck.slides[index].layout == .title ? palette.cover : palette.surface))
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.slides[index].title).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: deck.slides[index].layout == .title ? "#FFFFFF" : palette.ink))
                        .lineLimit(3)
                    Spacer(minLength: 0)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .aspectRatio(deck.effectiveAspectRatio.ratio, contentMode: .fit)
        .clipped()
        .task(id: identity) {
            image = nil
            let result = await ThumbnailRenderer.shared.image(html: HTMLRenderer.singleSlide(deck: deck, slideIndex: index), aspectRatio: deck.effectiveAspectRatio)
            guard !Task.isCancelled else { return }
            image = result
        }
        .accessibilityLabel("Slide \(index + 1) preview: \(deck.slides[index].title)")
    }
}

private struct ThumbnailIdentity: Equatable {
    let slide: Slide
    let theme: DeckTheme
    let footer: String
    let number: Int
    let count: Int
    let customCSS: String?
    let aspectRatio: DeckAspectRatio
}

/// One queued WebKit renderer avoids creating a web process for every slide row.
@MainActor final class ThumbnailRenderer: NSObject, WKNavigationDelegate {
    static let shared = ThumbnailRenderer()
    private let cache = NSCache<NSString, NSImage>()
    private var requests: [(UUID, String, NSString, CheckedContinuation<NSImage?, Never>, DeckAspectRatio)] = []
    private var processing = false
    private var webView: WKWebView?
    private var window: RenderHostPanel?
    private var activeNavigation: WKNavigation?
    private var navigationCompletion: ((Result<Void, Error>) -> Void)?

    override init() {
        super.init()
        cache.countLimit = 96
        cache.totalCostLimit = 24 * 1_024 * 1_024
    }

    func image(html: String, aspectRatio: DeckAspectRatio = .sixteenByNine) async -> NSImage? {
        let key = SHA256.hash(data: Data((aspectRatio.rawValue + html).utf8)).map { String(format: "%02x", $0) }.joined() as NSString
        if let image = cache.object(forKey: key) { return image }
        let id = UUID()
        return await withTaskCancellationHandler {
            guard !Task.isCancelled else { return nil }
            return await withCheckedContinuation { continuation in
                requests.append((id, html, key, continuation, aspectRatio))
                guard !processing else { return }
                processing = true
                Task { await drain() }
            }
        } onCancel: {
            Task { @MainActor in
                guard let index = self.requests.firstIndex(where: { $0.0 == id }) else { return }
                let request = self.requests.remove(at: index)
                request.3.resume(returning: nil)
            }
        }
    }

    private func drain() async {
        while !requests.isEmpty {
            let (_, html, key, continuation, aspectRatio) = requests.removeFirst()
            if let cached = cache.object(forKey: key) { continuation.resume(returning: cached); continue }
            do {
                let view = prepareView()
                let size = NSSize(width: aspectRatio.width, height: aspectRatio.height)
                window?.setContentSize(size)
                view.setFrameSize(size)
                try await timed { finish in
                    self.navigationCompletion = finish
                    self.activeNavigation = view.loadHTMLString(html, baseURL: nil)
                }
                navigationCompletion = nil
                let _: Any = try await timed { finish in
                    view.callAsyncJavaScript("if(window.swiftRevealReady) await window.swiftRevealReady; return true;", arguments: [:], in: nil, in: .page) { finish($0) }
                }
                let result: NSImage = try await timed { finish in
                    let configuration = WKSnapshotConfiguration()
                    configuration.rect = CGRect(origin: .zero, size: size)
                    configuration.snapshotWidth = 256
                    view.takeSnapshot(with: configuration) { image, error in
                        if let image { finish(.success(image)) }
                        else { finish(.failure(error ?? ThumbnailError.failed)) }
                    }
                }
                cache.setObject(result, forKey: key, cost: Int(result.size.width * result.size.height * 16))
                continuation.resume(returning: result)
            } catch {
                webView?.stopLoading()
                continuation.resume(returning: nil)
            }
            navigationCompletion = nil
            activeNavigation = nil
        }
        processing = false
        window?.orderOut(nil)
    }

    private func prepareView() -> WKWebView {
        if let webView { window?.prepareForRendering(); return webView }
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 720), configuration: configuration)
        view.navigationDelegate = self
        let host = RenderHostPanel(content: view)
        host.prepareForRendering()
        window = host; webView = view
        return view
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation === activeNavigation else { return }
        navigationCompletion?(.success(())); navigationCompletion = nil
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === activeNavigation else { return }
        navigationCompletion?(.failure(error)); navigationCompletion = nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.webView(webView, didFail: navigation, withError: error)
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        navigationCompletion?(.failure(ThumbnailError.failed)); navigationCompletion = nil
        self.webView = nil; window?.close(); window = nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let scheme = navigationAction.request.url?.scheme
        decisionHandler(scheme == "about" || scheme == nil ? .allow : .cancel)
    }
    private func timed<T>(_ start: (@escaping (Result<T, Error>) -> Void) -> Void) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let operation = ThumbnailOperation(continuation)
            let timeout = DispatchWorkItem { operation.resolve(.failure(ThumbnailError.failed)) }
            operation.timeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
            start { operation.resolve($0) }
        }
    }
}

private enum ThumbnailError: Error { case failed }

@MainActor private final class ThumbnailOperation<T> {
    private var continuation: CheckedContinuation<T, Error>?
    var timeout: DispatchWorkItem?
    init(_ continuation: CheckedContinuation<T, Error>) { self.continuation = continuation }
    func resolve(_ result: Result<T, Error>) {
        guard let continuation else { return }
        self.continuation = nil; timeout?.cancel(); timeout = nil
        continuation.resume(with: result)
    }
}
