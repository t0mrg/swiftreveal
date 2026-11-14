import Foundation

/// Optional overrides leave the theme in control; old documents need no migration.
public struct BlockStyle: Codable, Equatable, Sendable {
    public var background: String?
    public var foreground: String?
    public var accent: String?
    public var headerBackground: String?
    public var headerForeground: String?
    public init(background: String? = nil, foreground: String? = nil, accent: String? = nil,
                headerBackground: String? = nil, headerForeground: String? = nil) {
        self.background = background; self.foreground = foreground; self.accent = accent
        self.headerBackground = headerBackground; self.headerForeground = headerForeground
    }
}

public struct SlideBackground: Codable, Equatable, Sendable {
    public var imageData: Data
    public var imageMIME: String
    public var imageFit: Bool
    public var overlayColor: String
    public var overlayOpacity: Double
    public var textColor: String
    public init(imageData: Data, imageMIME: String = "image/png", imageFit: Bool = false,
                overlayColor: String = "#102036", overlayOpacity: Double = 0.45, textColor: String = "#FFFFFF") {
        self.imageData = imageData; self.imageMIME = imageMIME; self.imageFit = imageFit
        self.overlayColor = overlayColor; self.overlayOpacity = overlayOpacity; self.textColor = textColor
    }
}

public enum HexColor {
    /// Only six-digit RGB colours reach generated CSS. Never interpolate arbitrary input.
    public static func normalized(_ value: String?) -> String? {
        guard let value, value.count == 7, value.first == "#",
              value.dropFirst().allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        return value.uppercased()
    }
}

public struct ThemePalette: Equatable, Sendable {
    public let surface, ink, secondary, muted, rule, tint, accent, deep, wash, cover, cover2: String
    public init(surface: String = "#FCFCFB", ink: String = "#171B22", secondary: String = "#555E6A", muted: String = "#858C96", rule: String = "#DFE3E9", tint: String = "#F0F3F7", accent: String, deep: String, wash: String, cover: String, cover2: String) {
        self.surface = surface; self.ink = ink; self.secondary = secondary; self.muted = muted
        self.rule = rule; self.tint = tint; self.accent = accent; self.deep = deep
        self.wash = wash; self.cover = cover; self.cover2 = cover2
    }
}

public extension DeckTheme {
    var palette: ThemePalette {
        switch self {
        case .azure: return ThemePalette(accent: "#2A78D6", deep: "#174D8F", wash: "#E7EFFA", cover: "#123D73", cover2: "#2A78D6")
        case .ocean: return ThemePalette(accent: "#087F8C", deep: "#085B65", wash: "#E1F1F0", cover: "#093E49", cover2: "#168B95")
        case .graphite: return ThemePalette(accent: "#7557B5", deep: "#4D3A7A", wash: "#EDE8F5", cover: "#252B38", cover2: "#535C71")
        case .forest: return ThemePalette(surface: "#FBFCF8", tint: "#EFF3E9", accent: "#3A7A4B", deep: "#245333", wash: "#E5EFDF", cover: "#163B2B", cover2: "#4E8061")
        case .ember: return ThemePalette(surface: "#FFFCF9", tint: "#F8EFE8", accent: "#C35426", deep: "#8B3819", wash: "#FBE8D9", cover: "#6A2D23", cover2: "#C66A35")
        case .plum: return ThemePalette(surface: "#FDFBFD", tint: "#F3ECF4", accent: "#9A477D", deep: "#6F315A", wash: "#F4E3EE", cover: "#46213D", cover2: "#98558D")
        case .sand: return ThemePalette(surface: "#FBF8F0", ink: "#342D25", secondary: "#63594B", muted: "#827668", rule: "#DED4C3", tint: "#F0E9DA", accent: "#8B681F", deep: "#624A1D", wash: "#EEE2C6", cover: "#53432C", cover2: "#9A8053")
        case .midnight: return ThemePalette(surface: "#182333", ink: "#F1F5FA", secondary: "#CFD9E6", muted: "#A3B5CA", rule: "#3F526A", tint: "#23344B", accent: "#73B6FA", deep: "#ACD5FF", wash: "#243F5B", cover: "#0A1525", cover2: "#263F62")
        case .monochrome: return ThemePalette(surface: "#FFFFFF", ink: "#151515", secondary: "#444444", muted: "#727272", rule: "#D7D7D7", tint: "#F0F0F0", accent: "#444444", deep: "#252525", wash: "#EAEAEA", cover: "#111111", cover2: "#555555")
        }
    }
}
