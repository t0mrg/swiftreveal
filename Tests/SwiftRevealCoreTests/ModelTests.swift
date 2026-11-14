import Foundation
import Testing
@testable import SwiftRevealCore

struct ModelTests {
    @Test func roundTripPreservesContentAndEmbeddedImage() throws {
        let original = Deck(title: "Evidence & uncertainty", slides: [Slide(title: "日本語 ≤ 0.05", blocks: [ContentBlock(kind: .figure, caption: "Source: example", imageData: Data([0, 1, 2, 255]))])])
        #expect(try Deck.decode(original.encoded()) == original)
    }
    @Test func rejectsUnknownFutureSchema() throws {
        var deck = Deck(); deck.schemaVersion = 99
        #expect(throws: (any Error).self) { try Deck.decode(deck.encoded()) }
    }
    @Test func rejectsEmptyDeckAndDuplicateIDs() throws {
        #expect(throws: (any Error).self) { try Deck.decode(Deck(slides: []).encoded()) }
        let slide = Slide.starter(.cards)
        #expect(throws: (any Error).self) { try Deck.decode(Deck(slides: [slide, slide]).encoded()) }
        var second = slide; second.id = UUID()
        #expect(throws: (any Error).self) { try Deck.decode(Deck(slides: [slide, second]).encoded()) }
    }
    @Test func rejectsInvalidSplit() throws {
        var slide = Slide(); slide.split = 1.5
        #expect(throws: (any Error).self) { try Deck.decode(Deck(slides: [slide]).encoded()) }
    }
    @Test func duplicatePreservesContentButReplacesIdentities() {
        let slide = Slide.starter(.cards), copy = slide.duplicated()
        #expect(slide.id != copy.id)
        #expect(Set(slide.blocks.map(\.id)).isDisjoint(with: Set(copy.blocks.map(\.id))))
        #expect(slide.blocks.map(\.body) == copy.blocks.map(\.body))
    }
    @Test func tableTSVPreservesEmptyCellsAndHandlesCRLF() {
        let table = TableData(tsv: "Item\tValue\tNote\r\nItem A\t42\t\r\nItem B\t\tExample\r\n")
        #expect(table.headers == ["Item", "Value", "Note"])
        #expect(table.rows == [["Item A", "42", ""], ["Item B", "", "Example"]])
        #expect(TableData(tsv: table.tsv) == table)
    }
    @Test func everyLayoutHasUsableStarter() throws {
        for layout in SlideLayout.allCases {
            let slide = Slide.starter(layout)
            #expect(slide.layout == layout)
            #expect(!slide.blocks.isEmpty)
            #expect(try Deck.decode(Deck(slides: [slide]).encoded()).slides.first == slide)
        }
    }
}
