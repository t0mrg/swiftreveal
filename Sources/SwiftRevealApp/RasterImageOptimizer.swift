import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Uses ImageIO's bounded thumbnail decoder instead of first allocating the
/// original full-resolution image. SVG is deliberately outside this pipeline.
enum RasterImageOptimizer {
    enum Preset: String, CaseIterable, Identifiable, Sendable {
        case balanced, highQuality, compact, original
        var id: String { rawValue }
        var label: String {
            switch self {
            case .balanced: return "Balanced"
            case .highQuality: return "High quality"
            case .compact: return "Compact"
            case .original: return "Original pixels and format"
            }
        }
        var maximumPixelSize: Int? {
            switch self {
            case .balanced: return 2560
            case .highQuality: return 4096
            case .compact: return 1920
            case .original: return nil
            }
        }
        var jpegQuality: Double {
            switch self {
            case .balanced: return 0.85
            case .highQuality: return 0.92
            case .compact: return 0.75
            case .original: return 1
            }
        }
    }

    struct Options: Equatable, Sendable {
        var preset: Preset
        var compressOpaquePNGAsJPEG: Bool
        var recompressJPEG: Bool
        init(preset: Preset = .balanced, compressOpaquePNGAsJPEG: Bool = false, recompressJPEG: Bool = false) {
            self.preset = preset
            self.compressOpaquePNGAsJPEG = compressOpaquePNGAsJPEG
            self.recompressJPEG = recompressJPEG
        }
    }

    struct Result: Sendable {
        let data: Data
        let mime: String
        /// Display-oriented pixel dimensions; zero for SVG, which is bypassed.
        let width: Int
        let height: Int
        let originalBytes: Int
        var bytesSaved: Int { originalBytes - data.count }
    }

    enum OptimizationError: LocalizedError {
        case invalidImage, invalidDimensions, dimensionsTooLarge, couldNotEncode
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "The file is not a supported raster image."
            case .invalidDimensions: return "The image does not have valid pixel dimensions."
            case .dimensionsTooLarge: return "The image is too large to convert at its original resolution. Choose Balanced, High quality or Compact."
            case .couldNotEncode: return "The optimized image could not be encoded."
            }
        }
    }

    static func optimize(data: Data, mime: String, options: Options = Options()) throws -> Result {
        if mime == "image/svg+xml" {
            return Result(data: data, mime: mime, width: 0, height: 0, originalBytes: data.count)
        }
        guard !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let sourceIdentifier = CGImageSourceGetType(source),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw OptimizationError.invalidImage
        }
        guard let rawWidth = pixelDimension(properties[kCGImagePropertyPixelWidth]),
              let rawHeight = pixelDimension(properties[kCGImagePropertyPixelHeight]) else {
            throw OptimizationError.invalidDimensions
        }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let swapsAxes = (5...8).contains(orientation)
        let displayedWidth = swapsAxes ? rawHeight : rawWidth
        let displayedHeight = swapsAxes ? rawWidth : rawHeight
        // ImageIO already guarantees this is a recognized image source. Avoid
        // dynamic LaunchServices UTType lookups, which are unnecessary here and
        // can be unavailable in a command-line/non-GUI test process.
        let isJPEG = sourceIdentifier as String == UTType.jpeg.identifier
        let isPNG = sourceIdentifier as String == UTType.png.identifier
        let sourceMIME = isJPEG ? "image/jpeg" : isPNG ? "image/png" : mime
        func unchanged() -> Result {
            Result(data: data, mime: sourceMIME, width: displayedWidth, height: displayedHeight, originalBytes: data.count)
        }
        // This preset also suppresses optional lossy format/quality changes.
        if options.preset == .original && (isJPEG || isPNG) { return unchanged() }
        let longest = max(rawWidth, rawHeight)
        let maximum = options.preset.maximumPixelSize ?? longest
        let needsResize = longest > maximum
        let mandatoryConversion = !isJPEG && !isPNG
        let optionalJPEGRecompression = isJPEG && options.recompressJPEG
        let optionalPNGCompression = isPNG && options.compressOpaquePNGAsJPEG
        if !needsResize && !mandatoryConversion && !optionalJPEGRecompression && !optionalPNGCompression {
            return unchanged()
        }
        // Default presets bound both axes to at most 4096. The Original preset
        // needs this preflight when an unsupported format must be converted.
        let scale = min(1, Double(maximum) / Double(longest))
        let outputPixels = ceil(Double(rawWidth) * scale) * ceil(Double(rawHeight) * scale)
        guard outputPixels <= 20_000_000 else { throw OptimizationError.dimensionsTooLarge }
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maximum, longest),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw OptimizationError.invalidImage
        }
        let pngCanBecomeJPEG: Bool
        if optionalPNGCompression { pngCanBecomeJPEG = !(try hasTransparentPixels(image)) }
        else { pngCanBecomeJPEG = false }
        if isPNG && !needsResize && !pngCanBecomeJPEG { return unchanged() }
        let outputJPEG = isJPEG || pngCanBecomeJPEG
        let encoded = try encode(image, jpeg: outputJPEG, quality: options.preset.jpegQuality)
        // Optional compression must save bytes. Resolution limits and conversion
        // from unsupported image formats take precedence over byte preservation.
        if !needsResize && !mandatoryConversion && encoded.count >= data.count { return unchanged() }
        return Result(data: encoded, mime: outputJPEG ? "image/jpeg" : "image/png",
                      width: image.width, height: image.height, originalBytes: data.count)
    }

    private static func pixelDimension(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        let dimension = number.doubleValue
        guard dimension.isFinite, dimension > 0, dimension <= Double(Int32.max), dimension.rounded() == dimension else { return nil }
        return Int(dimension)
    }

    private static func hasTransparentPixels(_ image: CGImage) throws -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let bytesPerRow = image.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        return try pixels.withUnsafeMutableBytes { bytes in
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,
                                          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw OptimizationError.invalidImage
            }
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] < 255 }
        }
    }

    private static func encode(_ image: CGImage, jpeg: Bool, quality: Double) throws -> Data {
        guard let output = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(output, (jpeg ? UTType.jpeg.identifier : UTType.png.identifier) as CFString, 1, nil) else {
            throw OptimizationError.couldNotEncode
        }
        var properties: [CFString: Any] = [kCGImagePropertyOrientation: 1]
        if jpeg { properties[kCGImageDestinationLossyCompressionQuality] = quality }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw OptimizationError.couldNotEncode }
        return output as Data
    }
}
