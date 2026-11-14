import Foundation
import Testing
@testable import SwiftRevealCore

struct AppearanceModelTests {
    @Test func unknownPaletteNamesFallBackToAzure() throws {
        let theme = try JSONDecoder().decode(DeckTheme.self, from: Data("\"unrecognized-palette\"".utf8))
        #expect(theme == .azure)
        #expect(DeckTheme.allCases.first == .azure)
    }

    @Test func defaultTablesContainOnlyGenericExamples() {
        let table = TableData()
        #expect(table.headers == ["Item", "Category", "Value"])
        #expect(table.rows == [["Item A", "Group 1", "42"], ["Item B", "Group 2", "28"]])
    }

    @Test func newDeckHasOnlyAnEmptyTitleSlide() {
        let deck = Deck.blank
        #expect(deck.slides.count == 1)
        #expect(deck.slides.first?.layout == .title)
        #expect(deck.slides.first?.blocks.isEmpty == true)
        #expect(deck.slides.first?.subtitle.isEmpty == true)
        #expect(deck.slides.first?.notes.isEmpty == true)
        #expect(deck.footer.isEmpty)
    }

    @Test func oldDocumentsWithoutAppearanceFieldsStillOpen() throws {
        let deck = Deck.sample
        var object = try #require(JSONSerialization.jsonObject(with: deck.encoded()) as? [String: Any])
        var slides = try #require(object["slides"] as? [[String: Any]])
        for index in slides.indices {
            slides[index].removeValue(forKey: "background")
            var blocks = try #require(slides[index]["blocks"] as? [[String: Any]])
            for blockIndex in blocks.indices { blocks[blockIndex].removeValue(forKey: "style") }
            slides[index]["blocks"] = blocks
        }
        object["slides"] = slides
        let opened = try Deck.decode(JSONSerialization.data(withJSONObject: object))
        #expect(opened == deck)
    }

    @Test func appearanceAndBackgroundSurviveSavingAndDuplication() throws {
        var slide = Slide.starter(.table)
        slide.blocks[0].style = BlockStyle(background: "#FAEFE0", foreground: "#321A07", accent: "#B25E18", headerBackground: "#804000", headerForeground: "#FFFFFF")
        slide.background = SlideBackground(imageData: Data([1, 2, 3]), imageFit: true, overlayColor: "#112233", overlayOpacity: 0.6, textColor: "#FFEECC")
        let deck = Deck(theme: .midnight, slides: [slide])
        #expect(try Deck.decode(deck.encoded()) == deck)
        let copy = slide.duplicated()
        #expect(copy.background == slide.background)
        #expect(copy.blocks[0].style == slide.blocks[0].style)
        #expect(copy.id != slide.id)
        #expect(copy.blocks[0].id != slide.blocks[0].id)
    }

    @Test func colorValidationRejectsCSSAndAcceptsRGB() {
        #expect(HexColor.normalized("#a0B1c2") == "#A0B1C2")
        for value in ["red", "#FFF", "#GG1234", "#FFFFFF;display:none", "#１２３４５６", "url(https://example.invalid)"] {
            #expect(HexColor.normalized(value) == nil)
        }
        #expect(HexColor.normalized(nil) == nil)
    }

    @Test func allThemesHaveDistinctValidPalettes() {
        #expect(DeckTheme.allCases.count == 9)
        #expect(Set(DeckTheme.allCases.map { $0.palette.accent }).count == 9)
        for theme in DeckTheme.allCases {
            let palette = theme.palette
            for color in [palette.surface, palette.ink, palette.secondary, palette.muted, palette.rule, palette.tint, palette.accent, palette.deep, palette.wash, palette.cover, palette.cover2] {
                #expect(HexColor.normalized(color) == color)
            }
        }
    }
}
