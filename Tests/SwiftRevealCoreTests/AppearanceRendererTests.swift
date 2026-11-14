import Foundation
import Testing
@testable import SwiftRevealCore

struct AppearanceRendererTests {
    @Test func everyThemeUsesItsSharedPalette() {
        for theme in DeckTheme.allCases {
            let deck = Deck(theme: theme)
            let html = HTMLRenderer.singleSlide(deck: deck, slideIndex: 0)
            #expect(html.contains("--surface:\(theme.palette.surface)"))
            #expect(html.contains("--accent:\(theme.palette.accent)"))
            #expect(html.contains("--ink:\(theme.palette.ink)"))
            #expect(html.contains("--cover:\(theme.palette.cover)"))
        }
        let dark = HTMLRenderer.singleSlide(deck: Deck(theme: .midnight), slideIndex: 0)
        #expect(dark.contains("tr:nth-child(even){background:var(--tint)}"))
        #expect(!dark.contains("background:#f4f5f7"))
    }

    @Test func blockAndTableOverridesAreScopedToTheirOwnBlock() {
        let styled = ContentBlock(kind: .table, style: BlockStyle(background: "#123456", foreground: "#abcdef", accent: "#778899", headerBackground: "#556677", headerForeground: "#FFEEDD"))
        let plain = ContentBlock(kind: .callout, body: "Still uses theme")
        let html = HTMLRenderer.singleSlide(deck: Deck(slides: [Slide(blocks: [styled, plain])]), slideIndex: 0)
        #expect(html.contains("class=\"sr-block block-table custom-bg custom-fg custom-accent custom-header-bg custom-header-fg\""))
        #expect(html.contains("--block-bg:#123456;--block-fg:#ABCDEF;--block-accent:#778899;--block-header-bg:#556677;--block-header-fg:#FFEEDD"))
        #expect(html.contains("class=\"sr-block block-callout\" data-block-id=\"\(plain.id.uuidString)\" aria-label=\"Block 2\" style=\";--block-font-scale:1.0\""))
        #expect(html.contains(".custom-bg tbody tr:nth-child(even){background:transparent}"))
        #expect(html.contains(".custom-header-fg th{color:var(--block-header-fg)}"))
    }

    @Test func malformedColoursCannotInjectMarkupOrCSS() {
        let attack = "#123456;background:url(https://example.invalid/tracker)"
        let background = SlideBackground(imageData: Data([1, 2, 3]), overlayColor: attack, textColor: "\"><script>bad()</script>")
        let block = ContentBlock(style: BlockStyle(background: attack, foreground: "red", accent: "#12345G"))
        let html = HTMLRenderer.singleSlide(deck: Deck(slides: [Slide(blocks: [block], background: background)]), slideIndex: 0)
        #expect(!html.contains("example.invalid"))
        #expect(!html.contains("bad()"))
        #expect(!html.contains("custom-bg\" data-block"))
        #expect(html.contains("--slide-text:#FFFFFF"))
        #expect(html.contains("style=\"background:#102036;opacity:0.45\""))
    }

    @Test func backgroundIsEmbeddedWithOverlayAndFitAcrossEveryExportPath() {
        let data = Data([0, 12, 100, 255])
        let image = SlideBackground(imageData: data, imageFit: true, overlayColor: "#fedcba", overlayOpacity: 0.7, textColor: "#123456")
        let deck = Deck(slides: [Slide(background: image)])
        let outputs = [HTMLRenderer.singleSlide(deck: deck, slideIndex: 0), HTMLRenderer.preview(deck: deck, slideIndex: 0), HTMLRenderer.export(deck: deck)]
        for html in outputs {
            #expect(html.contains("class=\"sr-slide has-background layout-"))
            #expect(html.contains("class=\"sr-background-layer\" aria-hidden=\"true\""))
            #expect(html.contains("data:image/png;base64,\(data.base64EncodedString())"))
            #expect(html.contains("style=\"object-fit:contain\""))
            #expect(html.contains("background:#FEDCBA;opacity:0.7"))
            #expect(html.contains("--slide-text:#123456"))
        }
    }

    @Test func unsupportedOrEmptyBackgroundsLeaveThemeUntouched() {
        let backgrounds = [SlideBackground(imageData: Data(), textColor: "#FF0000"), SlideBackground(imageData: Data([1]), imageMIME: "image/svg+xml", textColor: "#FF0000")]
        for background in backgrounds {
            let html = HTMLRenderer.singleSlide(deck: Deck(slides: [Slide(background: background)]), slideIndex: 0)
            #expect(!html.contains("class=\"sr-background-layer\""))
            #expect(!html.contains("--slide-text:#FF0000"))
            #expect(!html.contains("class=\"sr-slide has-background"))
        }
    }

    @Test func overlayOpacityIsClampedAndNonfiniteValuesDoNotReachCSS() {
        for (opacity, expected) in [(2.0,"1.0"),(-1.0,"0.0"),(Double.nan,"0.45"),(Double.infinity,"0.45")] {
            let background = SlideBackground(imageData: Data([1]), overlayOpacity: opacity)
            let html = HTMLRenderer.singleSlide(deck: Deck(slides: [Slide(background: background)]), slideIndex: 0)
            #expect(html.contains("background:#102036;opacity:\(expected)"))
        }
    }
}
