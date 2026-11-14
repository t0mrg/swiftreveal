import Foundation
import Testing
@testable import SwiftRevealCore

struct RendererTests {
    @Test func testHTMLContentIsEscapedInAllContexts() {
        let attack = "<script>alert(\"x\")</script>&'"
        let deck = Deck(title: attack, author: attack, footer: attack, slides: [Slide(title: attack, subtitle: attack, notes: attack, blocks: [ContentBlock(kind: .text, heading: attack, body: attack, caption: attack)])])
        let html = HTMLRenderer.export(deck: deck)
        #expect(!(html.contains(attack)))
        #expect(html.contains("&lt;script&gt;"))
        #expect(html.contains("&quot;x&quot;"))
        #expect(html.contains("connect-src 'none'"))
    }

    @Test func testPresentationIncludesBundledRevealAndNoExternalAssets() {
        let html = HTMLRenderer.export(deck: .sample)
        #expect(html.contains("reveal.js 5.2.0"))
        #expect(html.contains("new Reveal("))
        #expect(html.contains("Permission is hereby granted, free of charge"))
        #expect(html.contains("THE SOFTWARE IS PROVIDED"))
        #expect(!(html.contains("<script src=")))
        #expect(!(html.contains("<link ")))
        #expect(!(html.contains("sourceMappingURL=")))
        #expect(html.components(separatedBy: "<section>").count - 1 == Deck.sample.slides.count)
    }

    @Test func testEveryLayoutPreservesEveryBlock() {
        for layout in SlideLayout.allCases {
            let blocks = (1...7).map { ContentBlock(kind: .text, heading: "Unique heading \($0)", body: "Unique body \($0)") }
            let deck = Deck(slides: [Slide(layout: layout, blocks: blocks)])
            let html = HTMLRenderer.singleSlide(deck: deck, slideIndex: 0)
            for block in blocks {
                #expect(html.contains(block.heading))
                #expect(html.contains(block.body))
                #expect(html.contains(block.id.uuidString))
            }
        }
    }

    @Test func testPDFMarkupDoesNotScaleAndPreviewDoes() {
        let deck = Deck.sample
        let pdf = HTMLRenderer.singleSlide(deck: deck, slideIndex: 2)
        let preview = HTMLRenderer.preview(deck: deck, slideIndex: 2)
        #expect(pdf.contains("body class=\"sr-capture"))
        #expect(!(pdf.contains("function fitPreview()")))
        #expect(preview.contains("function fitPreview()"))
        #expect(pdf.contains("window.swiftRevealReady"))
        #expect(pdf.contains("slideIndex:2"))
        #expect(!(pdf.contains("<section>")))
    }

    @Test func testTableRetainsRaggedCellsAndSafeFormatting() {
        let block = ContentBlock(kind: .table, table: TableData(headers: ["First"], rows: [["A", "Extra <strong>cell</strong>"], ["B"]]))
        let html = HTMLRenderer.preview(deck: Deck(slides: [Slide(blocks: [block])]), slideIndex: 0)
        #expect(html.contains("Extra <strong>cell</strong>"))
        #expect(html.contains("<th scope=\"col\"></th>"))
        #expect(html.contains("<td>B</td><td></td>"))
    }

    @Test func testUntrustedImageMIMEIsNotInterpolated() {
        let block = ContentBlock(kind: .figure, imageData: Data("<script>bad</script>".utf8), imageMIME: "image/svg+xml\" onload=\"evil()")
        let html = HTMLRenderer.preview(deck: Deck(slides: [Slide(blocks: [block])]), slideIndex: 0)
        #expect(!(html.contains("evil()")))
        #expect(html.contains("Choose an image"))
    }

    @Test func testSampleDeckRoundTripsAndContainsAllLayouts() throws {
        let sample = Deck.sample
        #expect(try Deck.decode(sample.encoded()) == sample)
        #expect(Set(sample.slides.map(\.layout)) == Set(SlideLayout.allCases))
        #expect(sample.slides.filter { $0.layout == .figure || $0.layout == .figureAndText }.allSatisfy { $0.blocks.contains { $0.kind == .figure && $0.imageData != nil } })
    }

    @Test func testBasicEmphasisAndListsRemainTextOnly() {
        let block = ContentBlock(kind: .text, body: "**Strong**\n- First\n• Second\nOrdinary <unknown>text</unknown>")
        let html = HTMLRenderer.preview(deck: Deck(slides: [Slide(blocks: [block])]), slideIndex: 0)
        #expect(html.contains("<strong>Strong</strong>"))
        #expect(html.contains("<ul><li>First</li><li>Second</li></ul><p>Ordinary text</p>"))
    }

    @Test func testOutOfRangeSlideSelectionIsClamped() {
        #expect(HTMLRenderer.preview(deck: .sample, slideIndex: -20).contains("data-slide-index=\"0\""))
        #expect(HTMLRenderer.preview(deck: .sample, slideIndex: 100).contains("data-slide-index=\"7\""))
    }
}
