import Foundation

/// Themes contain portable CSS and a built-in base palette, never external assets.
public struct SavedTheme: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var name: String
    public var baseTheme: DeckTheme
    public var css: String
    public init(id: UUID = UUID(), name: String, baseTheme: DeckTheme, css: String) {
        schemaVersion = 1; self.id = id; self.name = name; self.baseTheme = baseTheme; self.css = css
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
    public static func decode(_ data: Data) throws -> SavedTheme {
        let theme = try JSONDecoder().decode(Self.self, from: data)
        guard theme.schemaVersion == 1 else { throw ThemeError.unsupportedVersion }
        guard !theme.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ThemeError.emptyName }
        return theme
    }
    public func applying(to deck: Deck) -> Deck {
        var result = deck; result.theme = baseTheme; result.customCSS = css; result.customThemeName = name; return result
    }
}

public enum ThemeError: LocalizedError {
    case unsupportedVersion, emptyName
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "This theme uses an unsupported file format."
        case .emptyName: return "Give the theme a name before saving."
        }
    }
}
