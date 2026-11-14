import Foundation

public enum SlideLayout: String, Codable, CaseIterable, Sendable {
    case title, statement, twoColumns, figureAndText, cards, metrics, table, figure
    public var label: String {
        switch self {
        case .title: return "Title"
        case .statement: return "Statement"
        case .twoColumns: return "Two columns"
        case .figureAndText: return "Figure + commentary"
        case .cards: return "Cards"
        case .metrics: return "Metrics"
        case .table: return "Table"
        case .figure: return "Full figure"
        }
    }
}

public enum BlockKind: String, Codable, CaseIterable, Sendable {
    case text, callout, metric, figure, table
    public var label: String { rawValue.capitalized }
}

public enum DeckTheme: String, Codable, CaseIterable, Sendable {
    case azure, ocean, graphite, forest, ember, plum, sand, midnight, monochrome
    public var label: String { rawValue.capitalized }
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .azure
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum SlideDensity: String, Codable, CaseIterable, Sendable {
    case comfortable, compact
    public var label: String { rawValue.capitalized }
}

public struct TableData: Codable, Equatable, Sendable {
    public var headers: [String]
    public var rows: [[String]]
    public init(headers: [String] = ["Item", "Category", "Value"], rows: [[String]] = [["Item A", "Group 1", "42"], ["Item B", "Group 2", "28"]]) {
        self.headers = headers; self.rows = rows
    }
    public init(tsv: String) {
        let lines = tsv.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var parsed = lines.map { $0.components(separatedBy: "\t") }
        while parsed.last == [""] { parsed.removeLast() }
        headers = parsed.first ?? [""]
        rows = Array(parsed.dropFirst())
    }
    public var tsv: String { ([headers] + rows).map { $0.joined(separator: "\t") }.joined(separator: "\n") }
}

public struct ContentBlock: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: BlockKind
    public var heading: String
    public var body: String
    public var caption: String
    public var imageData: Data?
    public var imageMIME: String
    public var imageFit: Bool
    public var table: TableData
    public var style: BlockStyle?
    public var fontScale: Double?
    public init(id: UUID = UUID(), kind: BlockKind = .text, heading: String = "", body: String = "", caption: String = "", imageData: Data? = nil, imageMIME: String = "image/png", imageFit: Bool = true, table: TableData = TableData(), style: BlockStyle? = nil, fontScale: Double? = nil) {
        self.id = id; self.kind = kind; self.heading = heading; self.body = body; self.caption = caption
        self.imageData = imageData; self.imageMIME = imageMIME; self.imageFit = imageFit; self.table = table; self.style = style; self.fontScale = fontScale
    }
    public static func starter(_ kind: BlockKind) -> ContentBlock {
        switch kind {
        case .text: return ContentBlock(kind: kind, heading: "Heading", body: "Write your key points here.\nStart a line with • or - for a bullet.")
        case .callout: return ContentBlock(kind: kind, heading: "Key point", body: "The finding your audience should remember.")
        case .metric: return ContentBlock(kind: kind, heading: "42", body: "A meaningful measure")
        case .figure: return ContentBlock(kind: kind, caption: "Figure caption and source")
        case .table: return ContentBlock(kind: kind, heading: "Example table")
        }
    }
}

public struct Slide: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var layout: SlideLayout
    public var kicker: String
    public var title: String
    public var subtitle: String
    public var notes: String
    public var split: Double
    public var density: SlideDensity
    public var blocks: [ContentBlock]
    public var background: SlideBackground?
    public var fontScale: Double?
    public init(id: UUID = UUID(), layout: SlideLayout = .twoColumns, kicker: String = "", title: String = "Untitled slide", subtitle: String = "", notes: String = "", split: Double = 0.5, density: SlideDensity = .comfortable, blocks: [ContentBlock] = [], background: SlideBackground? = nil, fontScale: Double? = nil) {
        self.id = id; self.layout = layout; self.kicker = kicker; self.title = title; self.subtitle = subtitle
        self.notes = notes; self.split = split; self.density = density; self.blocks = blocks; self.background = background; self.fontScale = fontScale
    }
    public static func starter(_ layout: SlideLayout) -> Slide {
        let blocks: [ContentBlock]
        switch layout {
        case .title: blocks = [ContentBlock(kind: .callout, heading: "The central message", body: "A concise introduction to your presentation.")]
        case .statement: blocks = [ContentBlock(kind: .text, body: "One clear idea, given room to breathe.")]
        case .twoColumns: blocks = [.starter(.text), .starter(.callout)]
        case .figureAndText: blocks = [.starter(.figure), .starter(.text)]
        case .cards: blocks = (1...4).map { ContentBlock(kind: .callout, heading: "Point \($0)", body: "Explain the evidence and its implication.") }
        case .metrics: blocks = (1...3).map { ContentBlock(kind: .metric, heading: "\($0 * 12)", body: "Measure \($0)") }
        case .table: blocks = [.starter(.table)]
        case .figure: blocks = [.starter(.figure)]
        }
        return Slide(layout: layout, title: layout == .title ? "Your presentation" : "Untitled slide", blocks: blocks)
    }
    public func duplicated() -> Slide {
        var copy = self; copy.id = UUID(); copy.blocks = blocks.map { block in var b = block; b.id = UUID(); return b }; return copy
    }
}

public struct Deck: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public var schemaVersion: Int
    public var title: String
    public var author: String
    public var footer: String
    public var theme: DeckTheme
    public var slides: [Slide]
    public var customCSS: String?
    public var customThemeName: String?
    public init(title: String = "Untitled presentation", author: String = "", footer: String = "SwiftReveal", theme: DeckTheme = .azure, slides: [Slide] = [Slide.starter(.title)], customCSS: String? = nil, customThemeName: String? = nil) {
        schemaVersion = Self.currentVersion; self.title = title; self.author = author; self.footer = footer; self.theme = theme; self.slides = slides; self.customCSS = customCSS; self.customThemeName = customThemeName
    }
    /// Start clean while keeping the tutorial deck available as a separate example.
    public static var blank: Deck {
        Deck(footer: "", slides: [Slide(layout: .title, title: "Your presentation")])
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
    public static func decode(_ data: Data) throws -> Deck {
        let result = try JSONDecoder().decode(Deck.self, from: data)
        guard result.schemaVersion == currentVersion else { throw DeckError.unsupportedVersion(result.schemaVersion) }
        guard !result.slides.isEmpty else { throw DeckError.emptyDeck }
        let slideIDs = result.slides.map(\.id)
        let blockIDs = result.slides.flatMap { $0.blocks.map(\.id) }
        guard Set(slideIDs).count == slideIDs.count, Set(blockIDs).count == blockIDs.count else { throw DeckError.duplicateIdentifiers }
        guard result.slides.allSatisfy({ $0.split.isFinite && (0.25...0.75).contains($0.split) }) else { throw DeckError.invalidSplit }
        return result
    }
}

public enum DeckError: LocalizedError {
    case unsupportedVersion(Int), emptyDeck, duplicateIdentifiers, invalidSplit
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "This presentation uses file format version \(version). This app supports version \(Deck.currentVersion)."
        case .emptyDeck: return "A presentation must contain at least one slide."
        case .duplicateIdentifiers: return "The presentation contains duplicate slide or block identifiers."
        case .invalidSplit: return "A slide has an invalid column split. The supported range is 25–75%."
        }
    }
}
