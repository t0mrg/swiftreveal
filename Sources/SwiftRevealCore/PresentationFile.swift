import Foundation
import Compression
import CryptoKit

/// On-disk storage is separate from the editable model and the portable JSON
/// export. Small decks stay plain JSON; larger decks can deduplicate assets and
/// losslessly compress the storage envelope without changing any image bytes.
public enum PresentationFile {
    public static let maximumFileBytes = 512 * 1_024 * 1_024
    public static let maximumDecodedBytes = 512 * 1_024 * 1_024
    public static let currentVersion = 1
    private static let magic = Data("SWRVDECK".utf8)
    private static let headerBytes = 60

    /// Recognizes the storage marker; decode still performs full validation.
    public static func isContainer(_ data: Data) -> Bool { data.starts(with: magic) }

    public static func encode(_ deck: Deck) throws -> Data {
        try encodeWithStatistics(deck).data
    }

    /// Use this when displaying save results to avoid encoding the same deck twice.
    public static func encodeWithStatistics(_ deck: Deck) throws -> (data: Data, statistics: PresentationFileStatistics) {
        let envelope = try AssetEnvelope(storing: deck)
        let legacy: Data
        do { legacy = try deck.encoded() }
        catch { throw PresentationFileError.invalidDocument }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let raw = try encoder.encode(envelope)
        guard raw.count <= maximumDecodedBytes else { throw PresentationFileError.decodedLimitExceeded }
        var payload = raw, codec: UInt8 = 0
        if let compressed = compressed(raw), meaningfulSaving(original: raw.count, candidate: compressed.count) {
            payload = compressed; codec = 1
        }
        let container = makeContainer(payload: payload, raw: raw, codec: codec)
        let useContainer = container.count <= maximumFileBytes && meaningfulSaving(original: legacy.count, candidate: container.count)
        let result = useContainer ? container : legacy
        guard result.count <= maximumFileBytes else { throw PresentationFileError.fileLimitExceeded }
        let statistics = PresentationFileStatistics(legacyJSONBytes: legacy.count, storedBytes: result.count,
            uniqueAssetCount: envelope.assets.count, imageReferenceCount: envelope.blockImages.count + envelope.backgroundImages.count,
            usesContainer: useContainer, usesCompression: useContainer && codec == 1)
        return (result, statistics)
    }

    /// Computes a complete candidate encoding. Prefer encodeWithStatistics at save time.
    public static func statistics(_ deck: Deck) throws -> PresentationFileStatistics {
        try encodeWithStatistics(deck).statistics
    }

    public static func decode(_ data: Data) throws -> Deck {
        guard data.count <= maximumFileBytes else { throw PresentationFileError.fileLimitExceeded }
        let data = Data(data) // Normalize indices when the caller passes a Data subsequence.
        guard data.starts(with: magic) else {
            if !data.isEmpty, data.count < magic.count, magic.starts(with: data) { throw PresentationFileError.truncatedFile }
            do { return try Deck.decode(data) }
            catch { throw PresentationFileError.invalidDocument }
        }
        guard data.count >= headerBytes else { throw PresentationFileError.truncatedFile }
        let version = Int(data[8]) << 8 | Int(data[9])
        guard version == currentVersion else { throw PresentationFileError.unsupportedVersion(version) }
        let codec = data[10]
        guard codec == 0 || codec == 1 else { throw PresentationFileError.unsupportedCodec(codec) }
        guard data[11] == 0 else { throw PresentationFileError.malformedHeader }
        let decodedLength = integer(data, at: 12), payloadLength = integer(data, at: 20)
        guard decodedLength > 0, decodedLength <= UInt64(maximumDecodedBytes) else { throw PresentationFileError.decodedLimitExceeded }
        guard payloadLength > 0, payloadLength <= UInt64(maximumFileBytes - headerBytes) else { throw PresentationFileError.fileLimitExceeded }
        let expectedFileLength = headerBytes + Int(payloadLength)
        guard data.count >= expectedFileLength else { throw PresentationFileError.truncatedFile }
        guard data.count == expectedFileLength else { throw PresentationFileError.malformedHeader }
        let payload = Data(data.dropFirst(headerBytes))
        // Hash stored bytes before allocation/decompression. Some LZFSE decoders
        // consume padding beyond their end marker; those bytes must be protected too.
        guard Data(SHA256.hash(data: payload)) == data.subdata(in: 28..<60) else { throw PresentationFileError.integrityCheckFailed }
        let raw: Data
        if codec == 0 {
            guard payload.count == Int(decodedLength) else { throw PresentationFileError.malformedHeader }
            raw = payload
        } else { raw = try decompressed(payload, expectedBytes: Int(decodedLength)) }
        let envelope: AssetEnvelope
        do { envelope = try JSONDecoder().decode(AssetEnvelope.self, from: raw) }
        catch { throw PresentationFileError.invalidEnvelope }
        return try envelope.restored()
    }

    private static func meaningfulSaving(original: Int, candidate: Int) -> Bool {
        guard candidate < original else { return false }
        let saving = original - candidate
        return saving >= 1_024 && Double(saving) / Double(original) >= 0.05
    }

    private static func makeContainer(payload: Data, raw: Data, codec: UInt8) -> Data {
        var result = magic
        result.append(contentsOf: [0, UInt8(currentVersion), codec, 0])
        appendInteger(UInt64(raw.count), to: &result)
        appendInteger(UInt64(payload.count), to: &result)
        result.append(contentsOf: SHA256.hash(data: payload))
        result.append(payload)
        return result
    }

    private static func appendInteger(_ value: UInt64, to data: inout Data) {
        for shift in stride(from: 56, through: 0, by: -8) { data.append(UInt8((value >> shift) & 0xFF)) }
    }
    private static func integer(_ data: Data, at offset: Int) -> UInt64 {
        data[offset..<(offset + 8)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    private static func compressed(_ data: Data) -> Data? {
        let capacity = data.count + max(65_536, data.count / 16)
        var output = Data(count: capacity)
        let count = output.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) -> Int in
            data.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> Int in
                guard let destination = destination.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let source = source.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                return compression_encode_buffer(destination, capacity, source, data.count, nil, COMPRESSION_LZFSE)
            }
        }
        guard count > 0 else { return nil }
        output.count = count
        return output
    }

    /// Allocate only the declared, capped decoded size plus one sentinel byte.
    /// Declared size and progress checks bound decoding and reject incomplete streams.
    /// The caller validates stored-payload SHA256 first, including any padding.
    private static func decompressed(_ data: Data, expectedBytes: Int) throws -> Data {
        var output = Data(count: expectedBytes + 1)
        try output.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) in
            try data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                guard let target = destination.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let sourcePointer = source.baseAddress?.assumingMemoryBound(to: UInt8.self) else { throw PresentationFileError.decompressionFailed }
                var stream = compression_stream(dst_ptr: target, dst_size: expectedBytes + 1, src_ptr: sourcePointer, src_size: data.count, state: nil)
                guard compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_LZFSE) == COMPRESSION_STATUS_OK else { throw PresentationFileError.decompressionFailed }
                defer { compression_stream_destroy(&stream) }
                stream.dst_ptr = target; stream.dst_size = expectedBytes + 1
                stream.src_ptr = sourcePointer; stream.src_size = data.count
                while true {
                    let beforeSource = stream.src_size, beforeTarget = stream.dst_size
                    let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                    if status == COMPRESSION_STATUS_END {
                        guard stream.src_size == 0, expectedBytes + 1 - stream.dst_size == expectedBytes else { throw PresentationFileError.decompressionFailed }
                        return
                    }
                    guard status == COMPRESSION_STATUS_OK, stream.dst_size > 0,
                          stream.src_size != beforeSource || stream.dst_size != beforeTarget else { throw PresentationFileError.decompressionFailed }
                }
            }
        }
        output.count = expectedBytes
        return output
    }

    private struct AssetEnvelope: Codable {
        let schemaVersion: Int
        var deck: Deck
        var assets: [String: Data]
        var blockImages: [String: String]
        var backgroundImages: [String: String]

        init(storing source: Deck) throws {
            schemaVersion = 1; deck = source
            assets = [:]; blockImages = [:]; backgroundImages = [:]
            var estimatedAssetJSONBytes = 0
            func asset(_ data: Data) throws -> String {
                let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                if assets[digest] == nil {
                    // Preflight base64 expansion before asking JSONEncoder to allocate it.
                    let estimate = ((data.count + 2) / 3) * 4
                    guard estimate <= PresentationFile.maximumDecodedBytes - estimatedAssetJSONBytes else { throw PresentationFileError.decodedLimitExceeded }
                    estimatedAssetJSONBytes += estimate
                    assets[digest] = data
                }
                return digest
            }
            for index in deck.slides.indices {
                if let background = deck.slides[index].background {
                    backgroundImages[deck.slides[index].id.uuidString] = try asset(background.imageData)
                    deck.slides[index].background?.imageData = Data()
                }
                for blockIndex in deck.slides[index].blocks.indices {
                    if let data = deck.slides[index].blocks[blockIndex].imageData {
                        blockImages[deck.slides[index].blocks[blockIndex].id.uuidString] = try asset(data)
                        deck.slides[index].blocks[blockIndex].imageData = nil
                    }
                }
            }
            // Validate identifiers, versions and layout using existing document rules,
            // while image bytes are absent to avoid a second large base64 allocation.
            do { _ = try Deck.decode(deck.encoded()) }
            catch { throw PresentationFileError.invalidDocument }
        }

        func restored() throws -> Deck {
            guard schemaVersion == 1 else { throw PresentationFileError.unsupportedEnvelopeVersion(schemaVersion) }
            do { _ = try Deck.decode(deck.encoded()) }
            catch { throw PresentationFileError.invalidDocument }
            for (digest, bytes) in assets {
                let actual = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                guard digest == actual else { throw PresentationFileError.invalidAssetDigest }
            }
            var result = deck, usedAssets = Set<String>()
            var remainingBlocks = Set(blockImages.keys), remainingBackgrounds = Set(backgroundImages.keys)
            for index in result.slides.indices {
                let slideID = result.slides[index].id.uuidString
                if result.slides[index].background != nil {
                    guard result.slides[index].background?.imageData.isEmpty == true, let digest = backgroundImages[slideID], let bytes = assets[digest] else { throw PresentationFileError.missingAsset }
                    result.slides[index].background?.imageData = bytes
                    usedAssets.insert(digest); remainingBackgrounds.remove(slideID)
                }
                for blockIndex in result.slides[index].blocks.indices {
                    guard result.slides[index].blocks[blockIndex].imageData == nil else { throw PresentationFileError.invalidEnvelope }
                    let blockID = result.slides[index].blocks[blockIndex].id.uuidString
                    if let digest = blockImages[blockID] {
                        guard let bytes = assets[digest] else { throw PresentationFileError.missingAsset }
                        result.slides[index].blocks[blockIndex].imageData = bytes
                        usedAssets.insert(digest); remainingBlocks.remove(blockID)
                    }
                }
            }
            guard remainingBlocks.isEmpty, remainingBackgrounds.isEmpty, usedAssets == Set(assets.keys) else { throw PresentationFileError.invalidEnvelope }
            return result
        }
    }
}

public struct PresentationFileStatistics: Equatable, Sendable {
    public let legacyJSONBytes: Int
    public let storedBytes: Int
    public let uniqueAssetCount: Int
    public let imageReferenceCount: Int
    public let usesContainer: Bool
    public let usesCompression: Bool
    /// Encoded file size. bytesSaved is the separate size reduction.
    public var savedBytes: Int { storedBytes }
    public var isCompressed: Bool { usesCompression }
    public var bytesSaved: Int { max(0, legacyJSONBytes - storedBytes) }
    public var savingsFraction: Double { legacyJSONBytes > 0 ? Double(bytesSaved) / Double(legacyJSONBytes) : 0 }
}

public enum PresentationFileError: LocalizedError, Equatable {
    case fileLimitExceeded, decodedLimitExceeded, unsupportedVersion(Int), unsupportedEnvelopeVersion(Int), unsupportedCodec(UInt8)
    case truncatedFile, malformedHeader, integrityCheckFailed, decompressionFailed, invalidEnvelope, invalidDocument, missingAsset, invalidAssetDigest
    public var errorDescription: String? {
        switch self {
        case .fileLimitExceeded: return "This presentation exceeds the 512 MB file-size limit."
        case .decodedLimitExceeded: return "The decoded presentation exceeds the 512 MB storage limit."
        case .unsupportedVersion(let version): return "This presentation uses storage version \(version). This app supports version \(PresentationFile.currentVersion)."
        case .unsupportedEnvelopeVersion(let version): return "This presentation uses unsupported asset-storage version \(version)."
        case .unsupportedCodec: return "This presentation uses an unsupported compression method."
        case .truncatedFile: return "The presentation file is incomplete or truncated."
        case .malformedHeader: return "The presentation file has an invalid storage header or length."
        case .integrityCheckFailed: return "The presentation failed its integrity check. Restore an undamaged copy."
        case .decompressionFailed: return "The presentation's compressed data is damaged or has an invalid length."
        case .invalidEnvelope: return "The presentation's asset-storage structure is invalid."
        case .invalidDocument: return "The presentation data is invalid or uses an unsupported document format."
        case .missingAsset: return "The presentation refers to an image asset that is missing."
        case .invalidAssetDigest: return "An image asset failed its integrity check."
        }
    }
}
