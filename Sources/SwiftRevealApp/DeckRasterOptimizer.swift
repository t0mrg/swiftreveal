import CryptoKit
import Foundation
import SwiftRevealCore

struct DeckOptimizationResult: Sendable {
    let original: Deck
    let optimized: Deck
    let before: PresentationFileStatistics
    let after: PresentationFileStatistics
    let changedImageReferences: Int
    let uniqueRasterImages: Int
    let warnings: [String]
}

enum DeckRasterOptimizer {
    static func analyze(_ source: Deck, options: RasterImageOptimizer.Options) throws -> DeckOptimizationResult {
        let before = try PresentationFile.statistics(source)
        if options.preset == .original {
            return DeckOptimizationResult(original: source, optimized: source, before: before, after: before,
                changedImageReferences: 0, uniqueRasterImages: 0, warnings: [])
        }
        var candidate = source
        var cache: [String: RasterImageOptimizer.Result] = [:]
        var failures: [String: String] = [:]
        var changed = 0
        var warnings: [String] = []
        func optimized(_ data: Data, mime: String, location: String) -> ImportedImageAsset {
            guard ["image/png", "image/jpeg", "image/tiff"].contains(mime) else {
                return ImportedImageAsset(data: data, mime: mime)
            }
            let key = mime + ":" + Data(SHA256.hash(data: data)).base64EncodedString()
            do {
                if let message = failures[key] {
                    warnings.append(location + ": " + message)
                    return ImportedImageAsset(data: data, mime: mime)
                }
                let result: RasterImageOptimizer.Result
                if let cached = cache[key] { result = cached }
                else {
                    result = try RasterImageOptimizer.optimize(data: data, mime: mime, options: options)
                    cache[key] = result
                }
                if result.data != data || result.mime != mime { changed += 1 }
                return ImportedImageAsset(data: result.data, mime: result.mime)
            } catch {
                failures[key] = error.localizedDescription
                warnings.append(location + ": " + error.localizedDescription)
                return ImportedImageAsset(data: data, mime: mime)
            }
        }
        for index in candidate.slides.indices {
            try Task.checkCancellation()
            if let background = candidate.slides[index].background {
                let asset = optimized(background.imageData, mime: background.imageMIME, location: "Slide \(index + 1) background")
                candidate.slides[index].background?.imageData = asset.data
                candidate.slides[index].background?.imageMIME = asset.mime
            }
            for blockIndex in candidate.slides[index].blocks.indices {
                try Task.checkCancellation()
                let block = candidate.slides[index].blocks[blockIndex]
                guard let data = block.imageData else { continue }
                let asset = optimized(data, mime: block.imageMIME, location: "Slide \(index + 1), block \(blockIndex + 1)")
                candidate.slides[index].blocks[blockIndex].imageData = asset.data
                candidate.slides[index].blocks[blockIndex].imageMIME = asset.mime
            }
        }
        let after = try PresentationFile.statistics(candidate)
        return DeckOptimizationResult(original: source, optimized: candidate, before: before, after: after,
                                      changedImageReferences: changed, uniqueRasterImages: cache.count, warnings: warnings)
    }
}
