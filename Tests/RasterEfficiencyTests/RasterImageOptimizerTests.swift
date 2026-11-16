import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SwiftRevealApp

@Suite(.serialized)
struct RasterImageOptimizerTests {
    @Test func importPreservesInBoundsJPEGAndPNGByteForByte() throws {
        let image = try fixture(width: 640, height: 360)
        for (mime, identifier) in [("image/jpeg", UTType.jpeg.identifier), ("image/png", UTType.png.identifier)] {
            let data = try encoded(image, type: identifier, quality: 0.94)
            let result = try RasterImageOptimizer.optimize(data: data, mime: mime)
            #expect(result.data == data)
            #expect(result.mime == mime)
            #expect(result.width == 640 && result.height == 360)
            #expect(result.originalBytes == data.count && result.bytesSaved == 0)
        }
    }

    @Test func defaultPNGOptimizationKeepsCrispDiagramPixelsAndFormat() throws {
        let image = try fixture(width: 1200, height: 600, diagram: true)
        let png = try encoded(image, type: UTType.png.identifier)
        let result = try RasterImageOptimizer.optimize(data: png, mime: "image/png")
        #expect(result.mime == "image/png")
        #expect(result.data == png)
        #expect(try decodedPixels(result.data) == decodedPixels(png))
    }

    @Test func presetsBoundResolutionWithoutUpscaling() throws {
        let large = try encoded(fixture(width: 5200, height: 1040), type: UTType.jpeg.identifier, quality: 0.95)
        for (preset, edge) in [(RasterImageOptimizer.Preset.balanced, 2560), (.highQuality, 4096), (.compact, 1920)] {
            let result = try RasterImageOptimizer.optimize(data: large, mime: "image/jpeg", options: .init(preset: preset))
            #expect(result.width == edge)
            #expect(abs(Double(result.height) - Double(edge) / 5) <= 1)
            #expect(result.mime == "image/jpeg")
            #expect(max(result.width, result.height) <= edge)
            #expect(result.data.count < large.count)
        }
        let small = try encoded(fixture(width: 80, height: 40), type: UTType.jpeg.identifier, quality: 0.98)
        let result = try RasterImageOptimizer.optimize(data: small, mime: "image/jpeg", options: .init(recompressJPEG: true))
        #expect(result.width == 80 && result.height == 40)
        #expect(result.data.count <= small.count)
    }

    @Test func opaquePhotoPNGCanBecomeJPEGOnlyWithExplicitPermission() throws {
        let png = try encoded(fixture(width: 1024, height: 768), type: UTType.png.identifier)
        let automatic = try RasterImageOptimizer.optimize(data: png, mime: "image/png")
        let photo = try RasterImageOptimizer.optimize(data: png, mime: "image/png", options: .init(compressOpaquePNGAsJPEG: true))
        #expect(automatic.data == png && automatic.mime == "image/png")
        #expect(photo.mime == "image/jpeg")
        #expect(photo.data.count < png.count / 2)
        #expect(photo.width == 1024 && photo.height == 768)
        #expect(photo.bytesSaved == png.count - photo.data.count)
        let reference = try decodedPixels(png), compressed = try decodedPixels(photo.data)
        var error = 0, samples = 0
        for offset in stride(from: 0, to: reference.count, by: 4 * 17) {
            for channel in 0..<3 { error += abs(Int(reference[offset + channel]) - Int(compressed[offset + channel])); samples += 1 }
        }
        #expect(Double(error) / Double(samples) < 12)
        print("Raster benchmark, opaque photo PNG: \(png.count) → \(photo.data.count) bytes (\(Int(100 * Double(photo.bytesSaved) / Double(png.count)))% smaller)")
    }

    @Test func existingJPEGRecompressionIsExplicitAndRetainsResolution() throws {
        let jpeg = try encoded(fixture(width: 1024, height: 768), type: UTType.jpeg.identifier, quality: 0.99)
        let imported = try RasterImageOptimizer.optimize(data: jpeg, mime: "image/jpeg", options: .init(preset: .compact))
        let optimized = try RasterImageOptimizer.optimize(data: jpeg, mime: "image/jpeg", options: .init(preset: .compact, recompressJPEG: true))
        #expect(imported.data == jpeg)
        #expect(optimized.mime == "image/jpeg")
        #expect(optimized.width == 1024 && optimized.height == 768)
        #expect(optimized.data.count < jpeg.count)
        print("Raster benchmark, existing JPEG: \(jpeg.count) → \(optimized.data.count) bytes (\(Int(100 * Double(optimized.bytesSaved) / Double(jpeg.count)))% smaller)")
    }

    @Test func transparencySurvivesExplicitPhotoModeAndDownsampling() throws {
        let original = try encoded(fixture(width: 3200, height: 800, transparent: true), type: UTType.png.identifier)
        let result = try RasterImageOptimizer.optimize(data: original, mime: "image/png", options: .init(preset: .compact, compressOpaquePNGAsJPEG: true))
        #expect(result.mime == "image/png")
        #expect(result.width == 1920 && result.height == 480)
        let alpha = try decodedPixels(result.data).enumerated().filter { $0.offset % 4 == 3 }.map(\.element)
        #expect(alpha.contains(where: { $0 < 250 }))
        #expect(alpha.contains(255))
        let small = try encoded(fixture(width: 64, height: 32, transparent: true), type: UTType.png.identifier)
        let unchanged = try RasterImageOptimizer.optimize(data: small, mime: "image/png", options: .init(compressOpaquePNGAsJPEG: true))
        #expect(unchanged.data == small && unchanged.mime == "image/png")
    }

    @Test func originalPresetBypassesAllOptionalLossyChanges() throws {
        let image = try fixture(width: 2800, height: 560)
        for (mime, identifier) in [("image/jpeg", UTType.jpeg.identifier), ("image/png", UTType.png.identifier)] {
            let data = try encoded(image, type: identifier)
            let result = try RasterImageOptimizer.optimize(data: data, mime: mime,
                options: .init(preset: .original, compressOpaquePNGAsJPEG: true, recompressJPEG: true))
            #expect(result.data == data)
            #expect(result.width == 2800 && result.height == 560)
            #expect(result.mime == mime)
        }
    }

    @Test func rotatedJPEGKeepsDisplayOrientationWhenResized() throws {
        let data = try encoded(fixture(width: 3000, height: 1000), type: UTType.jpeg.identifier, quality: 0.96, orientation: 6)
        let original = try RasterImageOptimizer.optimize(data: data, mime: "image/jpeg", options: .init(preset: .original))
        #expect(original.data == data)
        #expect(original.width == 1000 && original.height == 3000)
        let resized = try RasterImageOptimizer.optimize(data: data, mime: "image/jpeg", options: .init(preset: .compact))
        #expect(resized.width == 640 && resized.height == 1920)
        let source = try #require(CGImageSourceCreateWithData(resized.data as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1 == 1)
        // Verify real pixel orientation, not only the recorded dimensions. The
        // bottom-right blue feature must move to the bottom-left after rotation.
        let pixels = try decodedPixels(resized.data)
        let left = ((resized.height - 40) * resized.width + 40) * 4
        let right = (40 * resized.width + resized.width - 40) * 4
        #expect(pixels[left + 2] > pixels[left])
        #expect(pixels[right] > pixels[right + 2])
    }

    @Test func optionalCompressionNeverMakesTheFileLarger() throws {
        let image = try fixture(width: 24, height: 24, diagram: true)
        let png = try encoded(image, type: UTType.png.identifier)
        let jpeg = try encoded(image, type: UTType.jpeg.identifier, quality: 0.15)
        let pngResult = try RasterImageOptimizer.optimize(data: png, mime: "image/png", options: .init(compressOpaquePNGAsJPEG: true))
        let jpegResult = try RasterImageOptimizer.optimize(data: jpeg, mime: "image/jpeg", options: .init(preset: .highQuality, recompressJPEG: true))
        #expect(pngResult.data.count <= png.count)
        #expect(jpegResult.data.count <= jpeg.count)
        #expect(pngResult.data == png && pngResult.mime == "image/png")
        #expect(jpegResult.data == jpeg)
    }

    @Test func TIFFNormalizesAndMIMEIsDetectedRatherThanTrusted() throws {
        let image = try fixture(width: 80, height: 40)
        let tiff = try encoded(image, type: UTType.tiff.identifier)
        let result = try RasterImageOptimizer.optimize(data: tiff, mime: "image/tiff")
        #expect(result.mime == "image/png")
        #expect(result.width == 80 && result.height == 40)
        let jpeg = try encoded(image, type: UTType.jpeg.identifier)
        let detected = try RasterImageOptimizer.optimize(data: jpeg, mime: "image/png")
        #expect(detected.mime == "image/jpeg")
        #expect(detected.data == jpeg)
    }

    @Test func SVGBypassesRasterWorkAndInvalidRasterFails() throws {
        let svg = Data("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"/>".utf8)
        let result = try RasterImageOptimizer.optimize(data: svg, mime: "image/svg+xml", options: .init(preset: .compact, compressOpaquePNGAsJPEG: true, recompressJPEG: true))
        #expect(result.data == svg && result.mime == "image/svg+xml")
        #expect(result.bytesSaved == 0)
        #expect(throws: RasterImageOptimizer.OptimizationError.self) {
            try RasterImageOptimizer.optimize(data: Data([1, 2, 3]), mime: "image/jpeg")
        }
    }

    private func fixture(width: Int, height: Int, transparent: Bool = false, diagram: Bool = false) throws -> CGImage {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        var state: UInt32 = 12345
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                if diagram {
                    let ink = x % 120 < 4 || y % 80 < 4
                    bytes[offset] = ink ? 20 : 245; bytes[offset + 1] = ink ? 40 : 245; bytes[offset + 2] = ink ? 80 : 245
                } else {
                    state = state &* 1664525 &+ 1013904223
                    let noise = Int((state >> 24) & 31)
                    bytes[offset] = UInt8(min(255, 50 + x * 150 / width + noise))
                    bytes[offset + 1] = UInt8(min(255, 30 + y * 170 / height + noise))
                    bytes[offset + 2] = UInt8(min(255, 40 + (x + y) * 90 / (width + height) + noise))
                    if x < width / 4 && y < height / 4 { bytes[offset] = 230; bytes[offset + 1] = 20; bytes[offset + 2] = 15 }
                    if x > 3 * width / 4 && y > 3 * height / 4 { bytes[offset] = 15; bytes[offset + 1] = 20; bytes[offset + 2] = 230 }
                }
                if transparent && x < width / 3 { bytes[offset] = 0; bytes[offset + 1] = 0; bytes[offset + 2] = 0; bytes[offset + 3] = 0 }
            }
        }
        let data = Data(bytes)
        let provider = try #require(CGDataProvider(data: data as CFData))
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        return try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                    space: space, bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent))
    }

    private func encoded(_ image: CGImage, type: String, quality: Double = 0.9, orientation: Int = 1) throws -> Data {
        let bytes = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(bytes, type as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality, kCGImagePropertyOrientation: orientation] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return bytes as Data
    }

    private func decodedPixels(_ data: Data) throws -> [UInt8] {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }
}
