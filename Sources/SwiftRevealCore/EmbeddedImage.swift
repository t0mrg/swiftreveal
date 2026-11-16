import CryptoKit
import Foundation

/// The only image-data-to-HTML boundary. SVG stays vector, but never enters the
/// slide DOM: an isolated image document contains only revalidated SVG markup.
public enum EmbeddedImage {
    private static let rasterMIMETypes: Set<String> = ["image/png", "image/jpeg", "image/gif", "image/webp", "image/tiff"]
    private static let svgCache: NSCache<NSString, SVGCacheEntry> = {
        let cache = NSCache<NSString, SVGCacheEntry>()
        cache.countLimit = 64
        cache.totalCostLimit = 32 * 1_024 * 1_024
        return cache
    }()

    /// Validates supported image formats without base64-encoding raster data.
    /// SVG must pass the same cached sanitizer used by dataURL.
    public static func isSupported(data: Data, mime: String) -> Bool {
        guard !data.isEmpty else { return false }
        if rasterMIMETypes.contains(mime) { return true }
        return mime == "image/svg+xml" && dataURL(data: data, mime: mime) != nil
    }

    /// Returns nil for an unsupported format, empty content or rejected SVG.
    /// SVG is validated here even when it came directly from document JSON.
    public static func dataURL(data: Data, mime: String) -> String? {
        guard !data.isEmpty else { return nil }
        if rasterMIMETypes.contains(mime) {
            return "data:\(mime);base64," + data.base64EncodedString()
        }
        guard mime == "image/svg+xml", data.count <= SVGImage.maximumBytes else { return nil }
        let key = Data(SHA256.hash(data: data)).base64EncodedString() as NSString
        if let cached = svgCache.object(forKey: key) { return cached.url }
        let url = (try? SVGImage.sanitize(data)).map { "data:image/svg+xml;base64," + $0.base64EncodedString() }
        // A rejected input is cached too, so repeated previews do not keep
        // reparsing the same malformed or unsafe document image.
        svgCache.setObject(SVGCacheEntry(url), forKey: key, cost: (url?.utf8.count ?? 1) + key.length)
        return url
    }
}

private final class SVGCacheEntry: NSObject {
    let url: String?
    init(_ url: String?) { self.url = url }
}
