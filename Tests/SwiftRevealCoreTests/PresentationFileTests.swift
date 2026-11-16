import Foundation
import CryptoKit
import Testing
@testable import SwiftRevealCore

struct PresentationFileTests {
    private let magic = Data("SWRVDECK".utf8)

    private func bytes(_ count: Int, seed: UInt64 = 1) -> Data {
        var state = seed, data = Data(capacity: count)
        for _ in 0..<count {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            data.append(UInt8(truncatingIfNeeded: state))
        }
        return data
    }
    private func container(_ raw: Data, version: UInt16 = 1, codec: UInt8 = 0, decodedBytes: UInt64? = nil) -> Data {
        var result = magic
        result.append(contentsOf: [UInt8(version >> 8), UInt8(version & 0xFF), codec, 0])
        for integer in [decodedBytes ?? UInt64(raw.count), UInt64(raw.count)] {
            for shift in stride(from: 56, through: 0, by: -8) { result.append(UInt8((integer >> shift) & 0xFF)) }
        }
        result.append(contentsOf: SHA256.hash(data: raw)); result.append(raw)
        return result
    }
    private func envelope(_ deck: Deck, assets: [String: String] = [:], blocks: [String: String] = [:], backgrounds: [String: String] = [:], version: Int = 1) throws -> Data {
        let root: [String: Any] = ["schemaVersion": version, "deck": try JSONSerialization.jsonObject(with: deck.encoded()),
                                   "assets": assets, "blockImages": blocks, "backgroundImages": backgrounds]
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    @Test func legacyJSONStillOpensAndSmallDecksStayPlainJSON() throws {
        let deck = Deck.blank
        let legacy = try deck.encoded()
        #expect(try PresentationFile.decode(legacy) == deck)
        let saved = try PresentationFile.encodeWithStatistics(deck)
        #expect(saved.data == legacy)
        #expect(!saved.statistics.usesContainer)
        #expect(saved.statistics.bytesSaved == 0)
        #expect(saved.statistics.storedBytes == legacy.count)
        #expect(try Deck.decode(saved.data) == deck)
    }

    @Test func repeatedImageBytesAreStoredOnceAndAllDocumentValuesRoundTrip() throws {
        let image = bytes(32_768)
        let block = ContentBlock(kind: .figure, heading: "Figure", caption: "Original image", imageData: image,
                                 imageMIME: "image/jpeg", imageFit: false,
                                 style: BlockStyle(background: "#AABBCC", foreground: "#112233"), fontScale: 1.2)
        let background = SlideBackground(imageData: image, imageMIME: "image/jpeg", imageFit: true,
                                         overlayColor: "#123456", overlayOpacity: 0.4, textColor: "#FEDCBA")
        let slide = Slide(layout: .figure, kicker: "Section", title: "Figure & background", subtitle: "Δ = 0.5", notes: "Presenter notes",
                          split: 0.6, density: .compact, blocks: [block, .starter(.mermaid)], background: background,
                          fontScale: 0.9, centerTitleHorizontally: true, centerTitleVertically: false)
        let deck = Deck(title: "Document", author: "Author", footer: "Footer", theme: .plum,
                        slides: [slide, slide.duplicated(), slide.duplicated()], customCSS: ".accent {color:#112233}", customThemeName: "Saved theme")
        let originalJSON = try deck.encoded()
        let saved = try PresentationFile.encodeWithStatistics(deck)
        #expect(saved.data.starts(with: magic))
        #expect(saved.statistics.usesContainer)
        #expect(saved.statistics.usesCompression)
        #expect(saved.statistics.uniqueAssetCount == 1)
        #expect(saved.statistics.imageReferenceCount == 6)
        #expect(saved.statistics.savingsFraction > 0.8)
        #expect(try PresentationFile.decode(saved.data) == deck)
        var prefixed = Data([0xFF]); prefixed.append(saved.data)
        #expect(try PresentationFile.decode(prefixed.dropFirst()) == deck)
        #expect(try deck.encoded() == originalJSON)
        #expect(try Deck.decode(originalJSON) == deck)
        let reloaded = try PresentationFile.decode(saved.data)
        #expect(reloaded.slides[0].blocks[0].imageData == image)
        #expect(reloaded.slides[0].background?.imageData == image)
    }

    @Test func uniqueIncompressibleAssetsAreLosslessAndSavingsAreMeasuredHonestly() throws {
        let first = bytes(32_768, seed: 11), second = bytes(32_768, seed: 37)
        let deck = Deck(slides: [Slide(blocks: [ContentBlock(kind: .figure, imageData: first), ContentBlock(kind: .figure, imageData: second)])])
        let saved = try PresentationFile.encodeWithStatistics(deck)
        #expect(saved.statistics.uniqueAssetCount == 2)
        #expect(saved.statistics.imageReferenceCount == 2)
        #expect(saved.statistics.bytesSaved == saved.statistics.legacyJSONBytes - saved.data.count)
        #expect(saved.statistics.savingsFraction >= 0.05)
        #expect(try PresentationFile.decode(saved.data) == deck)
        print("Presentation storage, unique high-entropy fixtures: \(saved.statistics.legacyJSONBytes) → \(saved.statistics.storedBytes) bytes (\(Int(saved.statistics.savingsFraction * 100))% saved).")
        // These are byte-entropy fixtures, not a claim about photographic content.
    }

    @Test func explicitEmptyImagesRemainDifferentFromMissingImages() throws {
        let deck = Deck(slides: [Slide(blocks: [ContentBlock(kind: .figure, imageData: Data()), ContentBlock(kind: .figure, imageData: nil)],
                                      background: SlideBackground(imageData: Data()))])
        let rawEnvelope = try envelope(Deck(slides: [Slide(id: deck.slides[0].id, blocks: deck.slides[0].blocks.map { value in var copy = value; copy.imageData = nil; return copy }, background: SlideBackground(imageData: Data()))]),
                                      assets: [SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined(): ""],
                                      blocks: [deck.slides[0].blocks[0].id.uuidString: SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()],
                                      backgrounds: [deck.slides[0].id.uuidString: SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()])
        #expect(try PresentationFile.decode(container(rawEnvelope)) == deck)
        #expect(try PresentationFile.decode(PresentationFile.encode(deck)) == deck)
    }

    @Test func externalUncompressedEnvelopeIsSupportedAndVersionsAreValidated() throws {
        let deck = Deck.blank
        let raw = try envelope(deck)
        #expect(try PresentationFile.decode(container(raw)) == deck)
        #expect(throws: PresentationFileError.unsupportedVersion(2)) { try PresentationFile.decode(container(raw, version: 2)) }
        #expect(throws: PresentationFileError.unsupportedCodec(99)) { try PresentationFile.decode(container(raw, codec: 99)) }
        #expect(throws: PresentationFileError.unsupportedEnvelopeVersion(2)) { try PresentationFile.decode(container(envelope(deck, version: 2))) }
    }

    @Test func truncatedTamperedAndTrailingDataAreRejected() throws {
        let deck = Deck(slides: [Slide(title: String(repeating: "Repeated title ", count: 1_000))])
        let saved = try PresentationFile.encode(deck)
        #expect(saved.starts(with: magic))
        for length in [1, 7, 8, 20, 59, saved.count - 1] {
            #expect(throws: (any Error).self) { try PresentationFile.decode(Data(saved.prefix(length))) }
        }
        var wrongDigest = saved; wrongDigest[28] ^= 0xFF
        #expect(throws: PresentationFileError.integrityCheckFailed) { try PresentationFile.decode(wrongDigest) }
        var corruptPayload = saved; corruptPayload[corruptPayload.count - 1] ^= 0xFF
        #expect(throws: (any Error).self) { try PresentationFile.decode(corruptPayload) }
        var appended = saved; appended.append(0)
        #expect(throws: PresentationFileError.malformedHeader) { try PresentationFile.decode(appended) }
        var badFlags = saved; badFlags[11] = 1
        #expect(throws: PresentationFileError.malformedHeader) { try PresentationFile.decode(badFlags) }
        var wrongLength = saved; wrongLength[19] ^= 1
        #expect(throws: (any Error).self) { try PresentationFile.decode(wrongLength) }
        // Stored-byte integrity also covers decoder-ignored trailing padding.
        var adjusted = appended
        var length = UInt64(adjusted.count - 60)
        for index in stride(from: 27, through: 20, by: -1) { adjusted[index] = UInt8(length & 0xFF); length >>= 8 }
        #expect(throws: PresentationFileError.integrityCheckFailed) { try PresentationFile.decode(adjusted) }
    }

    @Test func declaredAndActualLimitsAreCheckedBeforeDecompression() throws {
        #expect(throws: PresentationFileError.fileLimitExceeded) { try PresentationFile.decode(Data(count: PresentationFile.maximumFileBytes + 1)) }
        #expect(throws: PresentationFileError.decodedLimitExceeded) {
            try PresentationFile.decode(container(Data("x".utf8), codec: 1, decodedBytes: UInt64(PresentationFile.maximumDecodedBytes) + 1))
        }
        #expect(throws: PresentationFileError.decodedLimitExceeded) { try PresentationFile.decode(container(Data("x".utf8), decodedBytes: 0)) }
        let bomb = Data([0x62, 0x76, 0x78, 0x32])
        #expect(throws: PresentationFileError.decompressionFailed) { try PresentationFile.decode(container(bomb, codec: 1, decodedBytes: 128)) }
    }

    @Test func missingCorruptAndOrphanedAssetsAreRejected() throws {
        let block = ContentBlock(kind: .figure), deck = Deck(slides: [Slide(blocks: [block])])
        let digest = SHA256.hash(data: Data([1, 2, 3])).map { String(format: "%02x", $0) }.joined()
        #expect(throws: PresentationFileError.missingAsset) { try PresentationFile.decode(container(envelope(deck, blocks: [block.id.uuidString: digest]))) }
        #expect(throws: PresentationFileError.invalidAssetDigest) { try PresentationFile.decode(container(envelope(deck, assets: [digest: Data([4, 5, 6]).base64EncodedString()], blocks: [block.id.uuidString: digest]))) }
        #expect(throws: PresentationFileError.invalidEnvelope) { try PresentationFile.decode(container(envelope(deck, assets: [digest: Data([1, 2, 3]).base64EncodedString()]))) }
        #expect(throws: PresentationFileError.invalidEnvelope) { try PresentationFile.decode(container(envelope(deck, assets: [digest: Data([1, 2, 3]).base64EncodedString()], blocks: [UUID().uuidString: digest]))) }
        let background = Deck(slides: [Slide(background: SlideBackground(imageData: Data()))])
        #expect(throws: PresentationFileError.missingAsset) { try PresentationFile.decode(container(envelope(background))) }
    }
}
