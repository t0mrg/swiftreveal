import Foundation
import Testing
@testable import SwiftRevealCore

struct SavedThemeTests {
    @Test func themeIsPortableAndRetainsCSSEditingSource() throws {
        let source = ".sr-slide { font-family: Georgia; }\n/* α and ≤ stay intact */\n.block-callout { border-radius: 0.5em; }"
        let original = SavedTheme(name: "Research notes", baseTheme: .forest, css: source)
        let decoded = try SavedTheme.decode(original.encoded())
        #expect(decoded == original)
        #expect(decoded.css == source)
    }

    @Test func applyingThemePreservesSlidesAndDocumentMetadata() {
        var deck = Deck.sample
        deck.title = "An existing presentation"; deck.author = "Researcher"; deck.footer = "Draft"
        let theme = SavedTheme(name: "Conference", baseTheme: .midnight, css: ".sr-slide h1 { color: #ffdd88; }")
        let result = theme.applying(to: deck)
        #expect(result.slides == deck.slides)
        #expect(result.title == deck.title)
        #expect(result.author == deck.author)
        #expect(result.footer == deck.footer)
        #expect(result.schemaVersion == deck.schemaVersion)
        #expect(result.theme == .midnight)
        #expect(result.customThemeName == "Conference")
        #expect(result.customCSS == theme.css)
    }

    @Test func deckContainsCustomThemeWithoutExternalLibraryDependency() throws {
        let theme = SavedTheme(name: "Portable", baseTheme: .ocean, css: ".sr-caption { color: #334455; }")
        let deck = theme.applying(to: Deck.blank)
        let restored = try Deck.decode(deck.encoded())
        #expect(restored.customCSS == theme.css)
        #expect(restored.customThemeName == theme.name)
        #expect(restored.theme == .ocean)
    }

    @Test func malformedAndFutureThemesAreRejected() throws {
        #expect(throws: (any Error).self) { try SavedTheme.decode(Data("not JSON".utf8)) }
        var future = SavedTheme(name: "Future", baseTheme: .azure, css: "")
        future.schemaVersion = 99
        #expect(throws: (any Error).self) { try SavedTheme.decode(future.encoded()) }
        let unnamed = SavedTheme(name: " \n", baseTheme: .azure, css: "")
        #expect(throws: (any Error).self) { try SavedTheme.decode(unnamed.encoded()) }
    }
}
