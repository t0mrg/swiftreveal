import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import SwiftRevealApp
import SwiftRevealCore

struct DeckRasterOptimizerTests {
    private func noisyPNG() throws -> Data {
        let width = 160, height = 120
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        var state: UInt32 = 42
        for index in stride(from: 0, to: pixels.count, by: 4) {
            for channel in 0..<3 {
                state = state &* 1664525 &+ 1013904223
                pixels[index + channel] = UInt8(truncatingIfNeeded: state >> 24)
            }
        }
        let image: CGImage = try pixels.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            return try #require(context.makeImage())
        }
        let data = try #require(CFDataCreateMutable(nil, 0))
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    @Test func wholeDeckOptimizationKeepsMetadataAndReusesOneRasterResult() throws {
        let originalBytes = try noisyPNG()
        let vector = try SVGImage.sanitize(SVGExamples.figure)
        let customStyle = BlockStyle(background: "#123456", foreground: "#FEDCBA")
        let original = Deck(title: "Keep title", author: "Keep author", footer: "Keep footer", theme: .plum,
            slides: [Slide(layout: .twoColumns, title: "Keep slide", notes: "Keep notes", blocks: [
                ContentBlock(kind: .figure, caption: "Keep caption", imageData: originalBytes, imageMIME: "image/png", style: customStyle),
                ContentBlock(kind: .figure, imageData: vector, imageMIME: "image/svg+xml")
            ], background: SlideBackground(imageData: originalBytes), fontScale: 1.1)], customCSS: ".sr-caption { font-style:italic; }")
        let result = try DeckRasterOptimizer.analyze(original, options: .init(preset: .balanced, compressOpaquePNGAsJPEG: true, recompressJPEG: true))
        #expect(result.changedImageReferences == 2)
        #expect(result.uniqueRasterImages == 1)
        #expect(result.warnings.isEmpty)
        #expect(result.optimized.slides[0].blocks[0].imageMIME == "image/jpeg")
        #expect(result.optimized.slides[0].background?.imageMIME == "image/jpeg")
        #expect(result.optimized.slides[0].blocks[0].imageData == result.optimized.slides[0].background?.imageData)
        #expect(result.optimized.slides[0].blocks[1].imageData == vector)
        #expect(result.after.savedBytes < result.before.savedBytes)
        var expected = original
        expected.slides[0].blocks[0].imageData = result.optimized.slides[0].blocks[0].imageData
        expected.slides[0].blocks[0].imageMIME = "image/jpeg"
        expected.slides[0].background?.imageData = result.optimized.slides[0].background!.imageData
        expected.slides[0].background?.imageMIME = "image/jpeg"
        #expect(result.optimized == expected)
        #expect(try PresentationFile.decode(PresentationFile.encode(result.optimized)) == result.optimized)
    }

    @Test func originalPresetChangesNoImageBytesAndStillMeasuresStorageSaving() throws {
        let image = try noisyPNG()
        let deck = Deck(slides: (1...4).map { Slide(title: "Slide \($0)", blocks: [ContentBlock(kind: .figure, imageData: image, imageMIME: "image/png")]) })
        let result = try DeckRasterOptimizer.analyze(deck, options: .init(preset: .original, compressOpaquePNGAsJPEG: true, recompressJPEG: true))
        #expect(result.optimized == deck)
        #expect(result.changedImageReferences == 0)
        #expect(result.after.uniqueAssetCount == 1)
        #expect(result.after.imageReferenceCount == 4)
        #expect(result.after.savedBytes < result.after.legacyJSONBytes / 2)
    }

    @Test func invalidRasterRemainsUntouchedWithLocationWarnings() throws {
        let invalid = Data([0, 1, 2])
        let source = Deck(slides: [Slide(blocks: [ContentBlock(kind: .figure, imageData: invalid, imageMIME: "image/png")], background: SlideBackground(imageData: invalid))])
        let result = try DeckRasterOptimizer.analyze(source, options: .init())
        #expect(result.optimized == source)
        #expect(result.changedImageReferences == 0)
        #expect(result.warnings.count == 2)
        #expect(result.warnings.contains { $0.contains("background") })
        #expect(result.warnings.contains { $0.contains("block 1") })
    }
}
