import Foundation

/// Portable clipboard data contains slide-local content only. Deck-wide styling
/// stays with the destination presentation, so unset colours inherit its theme.
public struct SlideTransfer: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    /// The limit applies to the encoded JSON, including base64-embedded images.
    public static let maximumDataSize = 100 * 1_024 * 1_024

    public let schemaVersion: Int
    public let slides: [Slide]

    public init(slides: [Slide]) throws {
        schemaVersion = Self.currentVersion
        self.slides = slides
        try validate()
    }

    /// Set iteration order never controls the clipboard: preserve document order.
    /// Stale IDs are ignored; an empty effective selection is an error.
    public init(copying selectedSlideIDs: Set<UUID>, from deck: Deck) throws {
        try self.init(slides: deck.slides.filter { selectedSlideIDs.contains($0.id) })
    }

    private enum CodingKeys: String, CodingKey { case schemaVersion, slides }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentVersion else { throw SlideTransferError.unsupportedVersion(schemaVersion) }
        slides = try container.decode([Slide].self, forKey: .slides)
        try validate()
    }

    public func encode(to encoder: Encoder) throws {
        try validate()
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(slides, forKey: .slides)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data: Data
        do { data = try encoder.encode(self) }
        catch let error as SlideTransferError { throw error }
        catch { throw SlideTransferError.malformedPayload }
        guard data.count <= Self.maximumDataSize else { throw SlideTransferError.tooLarge }
        return data
    }

    public static func decode(_ data: Data) throws -> SlideTransfer {
        guard data.count <= maximumDataSize else { throw SlideTransferError.tooLarge }
        do { return try JSONDecoder().decode(Self.self, from: data) }
        catch let error as SlideTransferError { throw error }
        catch { throw SlideTransferError.malformedPayload }
    }

    /// Inserts above the earliest selected target slide, or appends when no target
    /// matches. Only deck.slides changes; all presentation metadata remains intact.
    /// Each paste gets fresh identifiers, including when pasting into the source.
    @discardableResult
    public func insert(into deck: inout Deck, above selectedSlideIDs: Set<UUID>) throws -> [UUID] {
        try validate()
        let insertionIndex = deck.slides.firstIndex { selectedSlideIDs.contains($0.id) } ?? deck.slides.endIndex
        var usedIDs = Set(deck.slides.map(\.id) + deck.slides.flatMap { $0.blocks.map(\.id) }
                          + slides.map(\.id) + slides.flatMap { $0.blocks.map(\.id) })
        func newIdentifier() -> UUID {
            var candidate = UUID()
            while usedIDs.contains(candidate) { candidate = UUID() }
            usedIDs.insert(candidate)
            return candidate
        }
        let copies = slides.map { slide -> Slide in
            var copy = slide
            copy.id = newIdentifier()
            copy.blocks = slide.blocks.map { block in
                var copy = block
                copy.id = newIdentifier()
                return copy
            }
            return copy
        }
        deck.slides.insert(contentsOf: copies, at: insertionIndex)
        return copies.map(\.id)
    }

    private func validate() throws {
        guard schemaVersion == Self.currentVersion else { throw SlideTransferError.unsupportedVersion(schemaVersion) }
        guard !slides.isEmpty else { throw SlideTransferError.noSlides }
        let slideIDs = slides.map(\.id)
        let blockIDs = slides.flatMap { $0.blocks.map(\.id) }
        guard Set(slideIDs).count == slideIDs.count, Set(blockIDs).count == blockIDs.count else {
            throw SlideTransferError.duplicateIdentifiers
        }
        guard slides.allSatisfy({ $0.split.isFinite && (0.25...0.75).contains($0.split) }) else {
            throw SlideTransferError.invalidSplit
        }
    }
}

public enum SlideTransferError: LocalizedError, Equatable {
    case unsupportedVersion(Int), noSlides, tooLarge, malformedPayload, duplicateIdentifiers, invalidSplit

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "These copied slides use clipboard format version \(version). This app supports version \(SlideTransfer.currentVersion)."
        case .noSlides:
            return "Select one or more slides to copy."
        case .tooLarge:
            return "The copied slides exceed the 100 MB clipboard limit. Copy fewer slides or use smaller images."
        case .malformedPayload:
            return "The copied slide data is malformed or contains unsupported values."
        case .duplicateIdentifiers:
            return "The copied slide data contains duplicate slide or block identifiers."
        case .invalidSplit:
            return "A copied slide has an invalid column split. The supported range is 25–75%."
        }
    }
}
