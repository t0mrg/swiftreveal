import Foundation
import Testing
@testable import SwiftRevealCore

struct SlideTransferTests {
    @Test func copyUsesDocumentOrderAndOnlyIncludesSlideContent() throws {
        let slides = (1...4).map { Slide(title: "Slide \($0)") }
        let source = Deck(title: "Source deck metadata", author: "Source author", footer: "Source footer", theme: .forest,
                          slides: slides, customCSS: ".source-only { color: red; }", customThemeName: "Source custom theme")
        let original = source
        let payload = try SlideTransfer(copying: [slides[3].id, slides[1].id], from: source)
        #expect(payload.slides == [slides[1], slides[3]])
        #expect(source == original)
        let data = try payload.encoded()
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(root.keys) == ["schemaVersion", "slides"])
        let json = String(decoding: data, as: UTF8.self)
        for metadata in [source.title, source.author, source.footer, source.customCSS!, source.customThemeName!] {
            #expect(!json.contains(metadata))
        }
        #expect(try SlideTransfer.decode(data) == payload)
    }

    @Test func pasteInsertsAboveEarliestSelectedTargetAndKeepsDestinationSettings() throws {
        let imported = [Slide(title: "Copied first"), Slide(title: "Copied second")]
        let payload = try SlideTransfer(slides: imported)
        let original = Deck(title: "Destination", author: "Destination author", footer: "Destination footer", theme: .midnight,
                            slides: (1...4).map { Slide(title: "Target \($0)") }, customCSS: ".destination { color: blue; }", customThemeName: "Destination theme")
        var destination = original
        let ids = try payload.insert(into: &destination, above: [original.slides[3].id, original.slides[1].id])
        #expect(destination.slides.map(\.title) == ["Target 1", "Copied first", "Copied second", "Target 2", "Target 3", "Target 4"])
        #expect(ids == Array(destination.slides[1...2]).map(\.id))
        var expected = original
        expected.slides = destination.slides
        #expect(destination == expected)
        #expect(destination.slides[1].blocks.isEmpty)
    }

    @Test func embeddedFiguresBackgroundsAndAllLocalFormattingSurviveTransfer() throws {
        let figureBytes = Data([0, 1, 2, 255]), backgroundBytes = Data([5, 4, 3, 2, 1])
        let style = BlockStyle(background: "#AABBCC", foreground: "#112233", accent: "#445566", headerBackground: "#778899", headerForeground: "#FFFFFF")
        let figure = ContentBlock(kind: .figure, heading: "Figure", body: "**Description**", caption: "Figure source", imageData: figureBytes,
                                  imageMIME: "image/png", imageFit: false, style: style, fontScale: 0.8)
        let table = ContentBlock(kind: .table, heading: "Table", table: TableData(headers: ["Label", "Value"], rows: [["A", "42"]]), style: style)
        let diagram = ContentBlock(kind: .mermaid, body: "flowchart LR\n    A --> B", caption: "Diagram", fontScale: 1.2)
        let inherited = ContentBlock(kind: .callout, heading: "Inherit theme", body: "No colour overrides")
        let background = SlideBackground(imageData: backgroundBytes, imageMIME: "image/png", imageFit: true,
                                         overlayColor: "#334455", overlayOpacity: 0.25, textColor: "#F1F2F3")
        let slide = Slide(layout: .cards, kicker: "Section", title: "Local content", subtitle: "Subtitle", notes: "Private notes",
                          split: 0.6, density: .compact, blocks: [figure, table, diagram, inherited], background: background,
                          fontScale: 1.1, centerTitleHorizontally: true, centerTitleVertically: true)
        let source = Deck(theme: .azure, slides: [slide], customCSS: ".source { color: red; }")
        let transfer = try SlideTransfer.decode(SlideTransfer(copying: [slide.id], from: source).encoded())
        var target = Deck(theme: .plum, slides: [Slide(title: "Target")])
        let ids = try transfer.insert(into: &target, above: [target.slides[0].id])
        var pasted = try #require(target.slides.first)
        #expect(pasted.id == ids.first)
        #expect(pasted.id != slide.id)
        #expect(Set(pasted.blocks.map(\.id)).isDisjoint(with: Set(slide.blocks.map(\.id))))
        pasted.id = slide.id
        for index in pasted.blocks.indices { pasted.blocks[index].id = slide.blocks[index].id }
        #expect(pasted == slide)
        #expect(target.slides[0].blocks[0].imageData == figureBytes)
        #expect(target.slides[0].background?.imageData == backgroundBytes)
        #expect(target.slides[0].blocks[3].style == nil)
        #expect(target.theme == .plum)
        #expect(target.customCSS == nil)
        let html = HTMLRenderer.singleSlide(deck: target, slideIndex: 0)
        #expect(html.contains("theme-plum"))
        #expect(!html.contains(".source { color: red; }"))
        #expect(try Deck.decode(target.encoded()) == target)
    }

    @Test func repeatedPasteAndPasteIntoSourceAlwaysReplaceSlideAndBlockIdentities() throws {
        let original = Slide.starter(.cards)
        let payload = try SlideTransfer(slides: [original])
        var destination = Deck(slides: [original])
        let firstIDs = try payload.insert(into: &destination, above: [original.id])
        let secondIDs = try payload.insert(into: &destination, above: [original.id])
        #expect(firstIDs != secondIDs)
        #expect(destination.slides.map(\.title) == Array(repeating: original.title, count: 3))
        #expect(destination.slides.map(\.id) == firstIDs + secondIDs + [original.id])
        let allSlideIDs = destination.slides.map(\.id)
        let allBlockIDs = destination.slides.flatMap { $0.blocks.map(\.id) }
        #expect(Set(allSlideIDs).count == 3)
        #expect(Set(allBlockIDs).count == original.blocks.count * 3)
        #expect(destination.slides.last == original)
        #expect(try Deck.decode(destination.encoded()) == destination)
    }

    @Test func noMatchingTargetAppendsAndEmptyDestinationCanReceiveSlides() throws {
        let payload = try SlideTransfer(slides: [Slide(title: "Pasted")])
        for selection: Set<UUID> in [[], [UUID()]] {
            var target = Deck(slides: [Slide(title: "Existing")])
            _ = try payload.insert(into: &target, above: selection)
            #expect(target.slides.map(\.title) == ["Existing", "Pasted"])
        }
        var empty = Deck(slides: [])
        _ = try payload.insert(into: &empty, above: [])
        #expect(empty.slides.map(\.title) == ["Pasted"])
    }

    @Test func legacyDocumentSlidesTransferWithoutRequiringNewAppearanceFields() throws {
        let deck = Deck(slides: [Slide(title: "Legacy slide", blocks: [.starter(.text)])])
        var json = try #require(JSONSerialization.jsonObject(with: deck.encoded()) as? [String: Any])
        var slides = try #require(json["slides"] as? [[String: Any]])
        for key in ["background", "fontScale", "centerTitleHorizontally", "centerTitleVertically"] { slides[0].removeValue(forKey: key) }
        var blocks = try #require(slides[0]["blocks"] as? [[String: Any]])
        blocks[0].removeValue(forKey: "style"); blocks[0].removeValue(forKey: "fontScale")
        slides[0]["blocks"] = blocks; json["slides"] = slides
        let legacy = try Deck.decode(JSONSerialization.data(withJSONObject: json))
        let transfer = try SlideTransfer(copying: [legacy.slides[0].id], from: legacy)
        #expect(try SlideTransfer.decode(transfer.encoded()).slides == legacy.slides)
    }

    @Test func rejectsEmptyMalformedOversizedFutureAndInvalidSlidePayloads() throws {
        #expect(throws: SlideTransferError.noSlides) { try SlideTransfer(slides: []) }
        #expect(throws: SlideTransferError.noSlides) { try SlideTransfer(copying: [UUID()], from: .blank) }
        #expect(throws: SlideTransferError.malformedPayload) { try SlideTransfer.decode(Data("not JSON".utf8)) }
        #expect(throws: SlideTransferError.tooLarge) { try SlideTransfer.decode(Data(count: SlideTransfer.maximumDataSize + 1)) }
        #expect(throws: SlideTransferError.unsupportedVersion(99)) { try SlideTransfer.decode(Data("{\"schemaVersion\":99,\"slides\":[]}".utf8)) }
        let slide = Slide.starter(.cards)
        #expect(throws: SlideTransferError.duplicateIdentifiers) { try SlideTransfer(slides: [slide, slide]) }
        var duplicateBlocks = slide; duplicateBlocks.id = UUID()
        #expect(throws: SlideTransferError.duplicateIdentifiers) { try SlideTransfer(slides: [slide, duplicateBlocks]) }
        var invalid = slide; invalid.split = 0.9
        #expect(throws: SlideTransferError.invalidSplit) { try SlideTransfer(slides: [invalid]) }
        var root = try #require(JSONSerialization.jsonObject(with: SlideTransfer(slides: [slide]).encoded()) as? [String: Any])
        root["slides"] = []
        #expect(throws: SlideTransferError.noSlides) { try SlideTransfer.decode(JSONSerialization.data(withJSONObject: root)) }
        root["slides"] = ["not a slide"]
        #expect(throws: SlideTransferError.malformedPayload) { try SlideTransfer.decode(JSONSerialization.data(withJSONObject: root)) }
    }
}
