import Foundation
import Testing
@testable import SwiftRevealCore

struct FormattingModelTests {
    @Test func legacyDocumentsDefaultToOriginalAlignment() throws {
        let deck = Deck.blank
        let data = try deck.encoded()
        #expect(!String(decoding: data, as: UTF8.self).contains("centerTitle"))
        let slide = try #require(Deck.decode(data).slides.first)
        #expect(slide.centerTitleHorizontally == nil)
        #expect(slide.centerTitleVertically == nil)
    }

    @Test func alignmentAndMermaidSurviveSavingAndDuplication() throws {
        let deck = Deck.formattingExamples
        let loaded = try Deck.decode(deck.encoded())
        #expect(loaded == deck)
        let cover = loaded.slides[0].duplicated()
        #expect(cover.centerTitleHorizontally == true)
        #expect(cover.centerTitleVertically == true)
        let diagram = loaded.slides[1].duplicated()
        #expect(diagram.blocks.first?.kind == .mermaid)
        #expect(diagram.blocks.first?.body.contains("flowchart LR") == true)
        #expect(diagram.blocks.first?.id != loaded.slides[1].blocks.first?.id)
    }

    @Test func mermaidStarterContainsEditableSource() {
        let block = ContentBlock.starter(.mermaid)
        #expect(block.body.hasPrefix("flowchart LR"))
        #expect(block.body.contains("-->"))
        #expect(block.kind.label == "Mermaid diagram")
    }
}
