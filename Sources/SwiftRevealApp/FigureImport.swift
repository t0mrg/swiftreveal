import AppKit
import Foundation
import SwiftRevealCore

struct ImportedImageAsset {
    let data: Data
    let mime: String
}

/// Preserve validated SVG; normalize other selected media to embedded PNG.
enum FigureImport {
    static let maximumBytes = 20 * 1_024 * 1_024

    static func load(from url: URL) throws -> ImportedImageAsset {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw ImportError.invalidImage }
        guard (values.fileSize ?? maximumBytes + 1) <= maximumBytes else { throw ImportError.tooLarge }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumBytes else { throw ImportError.tooLarge }
        if url.pathExtension.lowercased() == "svg" {
            return ImportedImageAsset(data: try SVGImage.sanitize(data), mime: "image/svg+xml")
        }
        guard let image = NSImage(data: data), image.isValid,
              image.size.width > 0, image.size.height > 0 else { throw ImportError.invalidImage }

        let isPDF = url.pathExtension.lowercased() == "pdf"
        let representationWidth = image.representations.map(\.pixelsWide).max() ?? 0
        let representationHeight = image.representations.map(\.pixelsHigh).max() ?? 0
        let sourceWidth = isPDF ? image.size.width * 2 : CGFloat(max(representationWidth, Int(image.size.width)))
        let sourceHeight = isPDF ? image.size.height * 2 : CGFloat(max(representationHeight, Int(image.size.height)))
        let scale = min(1, 4096 / max(sourceWidth, sourceHeight))
        let width = max(1, Int(sourceWidth * scale))
        let height = max(1, Int(sourceHeight * scale))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw ImportError.invalidImage }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw ImportError.invalidImage }
        guard png.count <= maximumBytes else { throw ImportError.tooLarge }
        return ImportedImageAsset(data: png, mime: "image/png")
    }

    enum ImportError: LocalizedError {
        case tooLarge, invalidImage
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "Choose an image smaller than 20 MB, or export a smaller PNG."
            case .invalidImage: return "The file is not a supported image. Try an SVG, PNG, JPEG, TIFF or PDF."
            }
        }
    }
}
