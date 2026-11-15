import Foundation
import Testing
import CryptoKit
@testable import SwiftRevealCore

struct DiagramRendererTests {
    @Test func titleCenteringHasIndependentScopesAndRequiresAnEmptyTitleSlide() {
        for horizontal in [false, true] {
            for vertical in [false, true] {
                let slide = Slide(layout: .title, centerTitleHorizontally: horizontal, centerTitleVertically: vertical)
                let html = HTMLRenderer.singleSlide(deck: Deck(slides: [slide]), slideIndex: 0)
                #expect(html.contains("title-only"))
                #expect(html.contains("density-comfortable title-only" + (horizontal ? " title-center-horizontal" : "") + (vertical ? " title-center-vertical" : "") + "\" data-slide-index"))
            }
        }
        for slide in [Slide(layout: .title, blocks: [.starter(.text)], centerTitleHorizontally: true, centerTitleVertically: true), Slide(layout: .figure, centerTitleHorizontally: true, centerTitleVertically: true)] {
            let html = HTMLRenderer.singleSlide(deck: Deck(slides: [slide]), slideIndex: 0)
            #expect(!html.contains("density-comfortable title-only"))
        }
    }

    @Test func diagramSourceIsEncodedAcrossAllRenderingModesAndLibraryStaysOffline() throws {
        let source = "flowchart LR\n A[</script><script>bad()</script>] --> B[Output]"
        let deck = Deck(slides: [Slide(blocks: [ContentBlock(kind: .mermaid, heading: "Diagram", body: source)])])
        for html in [HTMLRenderer.singleSlide(deck: deck, slideIndex: 0), HTMLRenderer.preview(deck: deck, slideIndex: 0), HTMLRenderer.export(deck: deck)] {
            #expect(html.contains("data-source=\"\(Data(source.utf8).base64EncodedString())\""))
            #expect(!html.contains(source))
            #expect(html.contains("version:\"11.12.0\""))
            #expect(html.contains("window.swiftRevealDiagramsReady"))
            #expect(html.contains("await window.swiftRevealDiagramsReady"))
            #expect(html.contains("securityLevel:'strict'"))
            #expect(html.contains("htmlLabels:false"))
            #expect(html.contains("maxTextSize:50000, maxEdges:500"))
            #expect(html.contains("new DOMParser()"))
            #expect(html.contains("if(node.closest('svg')) return null"))
            #expect(html.contains("Copyright (c) 2014 - 2022 Knut Sveidqvist"))
            #expect(html.contains("Apache License"))
            #expect(!html.contains("<script src="))
            #expect(html.contains("connect-src 'none'"))
            let policy = try #require(html.components(separatedBy: "script-src ").dropFirst().first?.components(separatedBy: ";").first)
            let expression = try NSRegularExpression(pattern: #"<script>(.*?)</script>"#, options: [.dotMatchesLineSeparators])
            let matches = expression.matches(in: html, range: NSRange(html.startIndex..., in: html))
            #expect(matches.count == 3)
            for match in matches {
                let script = String(html[try #require(Range(match.range(at: 1), in: html))])
                let hash = Data(SHA256.hash(data: Data(script.utf8))).base64EncodedString()
                #expect(policy.contains("'sha256-\(hash)'"))
            }
        }
        let ordinary = HTMLRenderer.singleSlide(deck: .blank, slideIndex: 0)
        #expect(!ordinary.contains("version:\"11.12.0\""))
    }

    @Test func diagramTypographyAndCenterAnchorsAreRetainedAfterRemovingGeneratedStyles() {
        let deck = Deck(slides: [Slide(blocks: [ContentBlock(kind: .mermaid, body: "flowchart LR\n A[Input] --> B[Process]", fontScale: 0.8)], fontScale: 1.25)])
        let html = HTMLRenderer.singleSlide(deck: deck, slideIndex: 0)
        // Measurement and final rendering share one explicit font specification.
        #expect(html.contains("themeVariables:{fontFamily,fontSize:fontSize+'px'}"))
        #expect(html.contains("scratch.style.fontFamily = fontFamily"))
        #expect(html.contains("root.style.fontFamily = typography.fontFamily"))
        #expect(html.contains("root.style.fontSize = typography.fontSize + 'px'"))
        #expect(html.contains(".sr-mermaid svg text{fill:var(--block-fg,var(--ink));font-family:inherit}"))
        // Node geometry is computed around a middle-anchored label. Preserve the
        // anchor as SVG metadata as well as scoped CSS after stripping <style>.
        #expect(html.contains("text.setAttribute('text-anchor','middle')"))
        #expect(html.contains(".flowchart-label text,.flowchartTitleText){text-anchor:middle}"))
        #expect(html.contains("'font-family','font-size','font-style','font-weight'"))
        #expect(html.contains("if(node.closest('svg')) return null"))
        #expect(html.contains("--slide-font-scale:1.25"))
        #expect(html.contains("--block-font-scale:0.8"))
    }

    @Test func codeStylesKeepMonospaceIndentationAndReadableDefaultSizes() {
        let html = HTMLRenderer.export(deck: .blank)
        #expect(html.contains("font-size:calc(22px * var(--slide-font-scale,1) * var(--block-font-scale,1));line-height:1.35;white-space:pre-wrap"))
        #expect(html.contains("tab-size:4"))
        #expect(html.contains(".sr-copy pre code{display:block;padding:0"))
        #expect(html.contains(".sr-token-comment"))
    }
}
