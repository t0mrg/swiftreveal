import Foundation
import Testing
@testable import SwiftRevealCore

struct TypographyModelTests {
    @Test func oldDocumentsWithoutTypographyAndCSSFieldsStillOpen() throws {
        let deck = Deck.sample
        var object = try #require(JSONSerialization.jsonObject(with: deck.encoded()) as? [String: Any])
        object.removeValue(forKey: "customCSS"); object.removeValue(forKey: "customThemeName")
        var slides = try #require(object["slides"] as? [[String: Any]])
        for index in slides.indices {
            slides[index].removeValue(forKey: "fontScale")
            var blocks = try #require(slides[index]["blocks"] as? [[String: Any]])
            for block in blocks.indices { blocks[block].removeValue(forKey: "fontScale") }
            slides[index]["blocks"] = blocks
        }
        object["slides"] = slides
        #expect(try Deck.decode(JSONSerialization.data(withJSONObject: object)) == deck)
    }
    @Test func typographyAndCSSSurvivePersistenceAndDuplication() throws {
        var slide = Slide.starter(.cards)
        slide.fontScale = 1.2; slide.blocks[0].fontScale = 0.8
        let deck = Deck(slides: [slide], customCSS: ".sr-slide { font-family: Georgia, serif; }", customThemeName: "Editorial")
        #expect(try Deck.decode(deck.encoded()) == deck)
        let duplicate = slide.duplicated()
        #expect(duplicate.fontScale == 1.2)
        #expect(duplicate.blocks[0].fontScale == 0.8)
        #expect(duplicate.id != slide.id)
    }
    @Test func fontScaleDefaultsAndBoundsArePredictable() {
        #expect(FontScaling.effective(nil) == 1)
        #expect(FontScaling.effective(.nan) == 1)
        #expect(FontScaling.effective(.infinity) == 1)
        #expect(FontScaling.effective(-2) == 0.25)
        #expect(FontScaling.effective(12) == 4)
        #expect(FontScaling.effective(1.25) == 1.25)
    }
}
