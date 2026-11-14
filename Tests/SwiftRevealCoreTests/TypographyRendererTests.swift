import CryptoKit
import Foundation
import Testing
@testable import SwiftRevealCore

struct TypographyRendererTests {
    @Test func slideAndBlockFontFactorsHaveIndependentScopes() {
        let first = ContentBlock(kind: .callout, heading: "Heading", body: "Copy", caption: "Caption", fontScale: 0.8)
        let second = ContentBlock(kind: .table, fontScale: 1.5)
        let deck = Deck(slides: [Slide(title: "Title", blocks: [first, second], fontScale: 1.25)])
        for html in [HTMLRenderer.preview(deck: deck, slideIndex: 0), HTMLRenderer.singleSlide(deck: deck, slideIndex: 0), HTMLRenderer.export(deck: deck)] {
            #expect(html.contains("--slide-font-scale:1.25;--block-font-scale:1;"))
            #expect(html.contains("--block-font-scale:0.8"))
            #expect(html.contains("--block-font-scale:1.5"))
            // Font scaling never resizes the canvas or its geometric margins.
            #expect(html.contains("width:1280px;height:720px;padding:48px 64px 58px"))
        }
    }

    @Test func allBuiltInTextSizesIncludeBothFontFactors() throws {
        let html = HTMLRenderer.singleSlide(deck: .sample, slideIndex: 0)
        let css = try #require(html.components(separatedBy: "<style>").dropFirst().first?.components(separatedBy: "</style>").first)
        let sizes = try NSRegularExpression(pattern: #"(?<![-A-Za-z])font-size:([^;}]+)"#).matches(in: css, range: NSRange(css.startIndex..., in: css))
        #expect(sizes.count >= 20)
        for match in sizes {
            let value = String(css[try #require(Range(match.range(at: 1), in: css))])
            if value.hasSuffix("em") || value == "inherit" { continue }
            #expect(value.contains("var(--slide-font-scale,1)"), "Unscaled text: \(value)")
            #expect(value.contains("var(--block-font-scale,1)"), "Block scope missing: \(value)")
        }
    }

    @Test func invalidFactorsCannotBreakStyleAttributes() {
        let deck = Deck(slides: [Slide(blocks: [ContentBlock(fontScale: .nan)], fontScale: .infinity), Slide(fontScale: -100)])
        let first = HTMLRenderer.singleSlide(deck: deck, slideIndex: 0)
        let second = HTMLRenderer.singleSlide(deck: deck, slideIndex: 1)
        #expect(first.contains("--slide-font-scale:1.0"))
        #expect(first.contains("--block-font-scale:1.0"))
        #expect(second.contains("--slide-font-scale:0.25"))
        #expect(!first.contains("font-scale:nan"))
        #expect(!first.contains("font-scale:inf"))
    }

    @Test func customCSSCannotEscapeItsStyleElement() throws {
        let attack = #".sr-slide::before{content:"</style><script>window.injected=true</script>";}"#
        let html = HTMLRenderer.export(deck: Deck(customCSS: attack))
        #expect(!html.contains("</style><script>window.injected=true"))
        #expect(html.contains(#"\3C /style>\3C script>window.injected=true\3C /script>"#))
        #expect(html.components(separatedBy: "<script>").count - 1 == 2)
        #expect(html.components(separatedBy: "</style>").count - 1 == 1)
    }

    @Test func cspHashesMatchTheActualTrustedScriptBodies() throws {
        for html in [HTMLRenderer.singleSlide(deck: .blank, slideIndex: 0), HTMLRenderer.preview(deck: .blank, slideIndex: 0), HTMLRenderer.export(deck: .blank)] {
            let policy = try #require(html.components(separatedBy: "script-src ").dropFirst().first?.components(separatedBy: ";").first)
            #expect(!policy.contains("unsafe-inline"))
            let expression = try NSRegularExpression(pattern: #"<script>(.*?)</script>"#, options: [.dotMatchesLineSeparators])
            let matches = expression.matches(in: html, range: NSRange(html.startIndex..., in: html))
            #expect(matches.count == 2)
            for match in matches {
                let script = String(html[try #require(Range(match.range(at: 1), in: html))])
                let hash = Data(SHA256.hash(data: Data(script.utf8))).base64EncodedString()
                #expect(policy.contains("'sha256-\(hash)'"))
            }
            #expect(html.contains("connect-src 'none'"))
        }
    }

    @Test func customStylesApplyLastAndRenderingRemainsDeterministic() throws {
        let css = ".sr-slide { --accent: #123456; } .sr-heading { font-size: 1.5em; }"
        let deck = Deck(customCSS: css, customThemeName: "My theme")
        let html = HTMLRenderer.preview(deck: deck, slideIndex: 0)
        #expect(html == HTMLRenderer.preview(deck: deck, slideIndex: 0))
        let close = try #require(html.range(of: "</style>"))
        let custom = try #require(html.range(of: css))
        #expect(custom.upperBound <= close.lowerBound)
        #expect(!html[custom.upperBound..<close.lowerBound].contains("font-size:"))
    }

    @Test func customAbsoluteFontSizesUseTheTrustedComputedFontPass() throws {
        let deck = Deck(slides: [Slide(blocks: [ContentBlock(kind: .text, body: "<small>Relative text</small>", fontScale: 0.8)], fontScale: 1.5)], customCSS: ".sr-copy { font-size: 40px !important; }")
        let html = HTMLRenderer.singleSlide(deck: deck, slideIndex: 0)
        #expect(html.contains("window.swiftRevealApplyFontScaling = function()"))
        #expect(html.contains("getComputedStyle(node).fontSize"))
        #expect(html.contains("node.style.setProperty(name,'1','important')"))
        #expect(html.contains("slideFactor*(blockFactors.get(block) ?? 1)"))
        #expect(html.contains("node.style.setProperty('font-size',(pixels*scale)+'px','important')"))
        let measure = try #require(html.range(of: "measured=[slide,...slide.querySelectorAll('*')].map"))
        let apply = try #require(html.range(of: "measured.forEach(([node,pixels,scale])"))
        #expect(measure.lowerBound < apply.lowerBound)
        // The pass runs only after fonts are ready and before the layout report.
        #expect(html.contains("await document.fonts.ready;\n  window.swiftRevealApplyFontScaling();"))
    }

    @Test func richFormattingWorksAcrossAllTextSlotsWithoutExecutableHTML() {
        let block = ContentBlock(kind: .table, heading: "**Evidence** <sup>1</sup>", caption: "<em>Source</em>", table: TableData(headers: ["H<sub>2</sub>O"], rows: [["<strong>Value</strong>"]]))
        let deck = Deck(footer: "<u>Footer</u>", slides: [Slide(kicker: "<b>Study</b>", title: "CO<sub>2</sub>", subtitle: "<em>Subtitle</em>", blocks: [block])])
        let html = HTMLRenderer.singleSlide(deck: deck, slideIndex: 0)
        for value in ["<sub>2</sub>", "<sup>1</sup>", "<em>Subtitle</em>", "<em>Source</em>", "<strong>Value</strong>", "<u>Footer</u>"] {
            #expect(html.contains(value))
        }
    }
}
