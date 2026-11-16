import Foundation
import Testing
@testable import SwiftRevealCore

struct AspectRatioTests {
    @Test func legacyFilesKeepWideCanvas() throws {
        let original = Deck.sample
        let data = try original.encoded()
        #expect(!String(decoding: data, as: UTF8.self).contains("aspectRatio"))
        let restored = try Deck.decode(data)
        #expect(restored.effectiveAspectRatio == .sixteenByNine)
        #expect(restored.effectiveAspectRatio.width == 1280)
        #expect(restored.effectiveAspectRatio.height == 720)
    }

    @Test func aspectRatioSurvivesBothStorageFormats() throws {
        var deck = Deck.sample
        deck.aspectRatio = .sixByFour
        #expect(try Deck.decode(deck.encoded()) == deck)
        #expect(try PresentationFile.decode(PresentationFile.encode(deck)) == deck)
        #expect(deck.effectiveAspectRatio.ratio == 1.5)
        let slides = deck.slides
        deck.aspectRatio = .sixteenByNine
        #expect(deck.slides == slides)
    }

    @Test func allRenderModesUseSelectedCanvas() {
        for ratio in DeckAspectRatio.allCases {
            var deck = Deck.sample
            deck.aspectRatio = ratio
            for html in [HTMLRenderer.preview(deck: deck, slideIndex: 0),
                         HTMLRenderer.singleSlide(deck: deck, slideIndex: 0),
                         HTMLRenderer.export(deck: deck)] {
                #expect(html.contains("width:\(ratio.width)px;height:\(ratio.height)px"))
            }
            #expect(HTMLRenderer.preview(deck: deck, slideIndex: 0)
                .contains("innerWidth/\(ratio.width),innerHeight/\(ratio.height)"))
            #expect(HTMLRenderer.export(deck: deck).contains("width:\(ratio.width),height:\(ratio.height)"))
        }
    }
}
