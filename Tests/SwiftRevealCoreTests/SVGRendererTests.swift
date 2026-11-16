import Foundation
import Testing
@testable import SwiftRevealCore

struct SVGRendererTests {
    private let source = """
    <svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">
      <defs>
        <linearGradient id="paint"><stop offset="0" stop-color="#087F8C"/><stop offset="1" stop-color="#2A78D6"/></linearGradient>
        <clipPath id="frame"><rect x="10" y="10" width="620" height="340" rx="20"/></clipPath>
      </defs>
      <g clip-path="url(#frame)"><rect width="640" height="360" fill="url(#paint)"/>
      <text x="320" y="190" text-anchor="middle" fill="white" font-family="Arial" font-size="32">Vector label</text></g>
    </svg>
    """

    @Test func validatedSVGRemainsVectorAndIsolatedAcrossEveryRenderMode() throws {
        let data = Data(source.utf8)
        let expectedURL = try #require(EmbeddedImage.dataURL(data: data, mime: "image/svg+xml"))
        let decoded = try #require(Data(base64Encoded: String(expectedURL.split(separator: ",", maxSplits: 1)[1])))
        let svg = try #require(String(data: decoded, encoding: .utf8))
        #expect(svg.contains("<svg"))
        #expect(svg.contains("linearGradient"))
        #expect(svg.contains("clipPath"))
        #expect(svg.contains("Vector label"))
        #expect(!expectedURL.hasPrefix("data:image/png"))
        for fit in [true, false] {
            let figure = ContentBlock(kind: .figure, heading: "SVG figure", imageData: data, imageMIME: "image/svg+xml", imageFit: fit)
            let background = SlideBackground(imageData: data, imageMIME: "image/svg+xml", imageFit: fit, overlayColor: "#123456", overlayOpacity: 0.35, textColor: "#FFFFFF")
            let deck = Deck(slides: [Slide(layout: .figure, blocks: [figure], background: background)])
            for html in [HTMLRenderer.preview(deck: deck, slideIndex: 0), HTMLRenderer.singleSlide(deck: deck, slideIndex: 0), HTMLRenderer.export(deck: deck)] {
                #expect(html.components(separatedBy: expectedURL).count - 1 == 2)
                #expect(html.contains("style=\"object-fit:\(fit ? "contain" : "cover")\""))
                #expect(html.contains("background:#123456;opacity:0.35"))
                #expect(html.contains("--slide-text:#FFFFFF"))
                // IDs and styles are inside isolated image documents rather
                // than becoming part of the slide or another figure's DOM.
                #expect(!html.contains("id=\"paint\""))
                #expect(!html.contains("id=\"frame\""))
                #expect(html.contains("img-src data:"))
                #expect(html.contains("connect-src 'none'"))
                #expect(!html.contains("<img src=\"http"))
            }
        }
    }

    @Test func SVGBytesAndMIMEPersistThroughSaveDuplicateAndCopy() throws {
        let data = try SVGImage.sanitize(Data(source.utf8))
        let figure = ContentBlock(kind: .figure, imageData: data, imageMIME: "image/svg+xml", imageFit: false)
        let slide = Slide(layout: .figure, blocks: [figure], background: SlideBackground(imageData: data, imageMIME: "image/svg+xml", imageFit: true))
        let saved = try Deck.decode(Deck(slides: [slide]).encoded())
        let duplicated = saved.slides[0].duplicated()
        let transfer = try SlideTransfer.decode(SlideTransfer(copying: [slide.id], from: saved).encoded())
        var transferred = Deck(theme: .midnight, slides: [Slide(title: "Destination")])
        try transfer.insert(into: &transferred, above: [transferred.slides[0].id])
        for target in [saved, transferred] {
            #expect(target.slides[0].blocks[0].imageData == data)
            #expect(target.slides[0].blocks[0].imageMIME == "image/svg+xml")
            #expect(target.slides[0].background?.imageData == data)
            #expect(target.slides[0].background?.imageMIME == "image/svg+xml")
            #expect(target.slides[0].blocks[0].imageFit == false)
            #expect(target.slides[0].background?.imageFit == true)
        }
        #expect(transferred.slides[0].id != slide.id)
        #expect(transferred.slides[0].blocks[0].id != figure.id)
        #expect(transferred.theme == .midnight)
        #expect(HTMLRenderer.singleSlide(deck: transferred, slideIndex: 0).contains("data:image/svg+xml;base64,"))
        #expect(duplicated.blocks[0].imageData == data)
        #expect(duplicated.background?.imageData == data)
        #expect(duplicated.id != slide.id)
        #expect(duplicated.blocks[0].id != figure.id)
    }

    @Test func malformedAndUnsupportedImagesNeverEnterTheRenderer() {
        let malformed = Data("<svg xmlns=\"http://www.w3.org/2000/svg\"><g>".utf8)
        for data in [Data(), Data([1, 2, 3]), malformed] {
            #expect(EmbeddedImage.dataURL(data: data, mime: "image/svg+xml") == nil)
            let deck = Deck(slides: [Slide(blocks: [ContentBlock(kind: .figure, imageData: data, imageMIME: "image/svg+xml")], background: SlideBackground(imageData: data, imageMIME: "image/svg+xml", textColor: "#ABCDEF"))])
            let html = HTMLRenderer.singleSlide(deck: deck, slideIndex: 0)
            #expect(html.contains("sr-placeholder"))
            #expect(!html.contains("data:image/svg+xml;base64,"))
            #expect(!html.contains("class=\"sr-background-layer\""))
            #expect(!html.contains("--slide-text:#ABCDEF"))
            #expect(html.contains("SVG unavailable"))
            #expect(html.contains("Background SVG unavailable"))
            #expect(html.components(separatedBy: "data-image-warning=\"").count - 1 == 2)
            #expect(html.contains("document.querySelectorAll('[data-image-warning]')"))
        }
        #expect(EmbeddedImage.dataURL(data: Data(source.utf8), mime: "text/html") == nil)
        #expect(EmbeddedImage.dataURL(data: Data(source.utf8), mime: "image/svg+xml\" onload=\"bad()") == nil)
    }

    @Test func editedDocumentSVGIsRevalidatedRatherThanTrusted() {
        let attack = Data("""
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><script>bad()</script>
        <image href="https://example.invalid/tracker.png" width="100" height="100"/></svg>
        """.utf8)
        let deck = Deck(slides: [Slide(blocks: [ContentBlock(kind: .figure, imageData: attack, imageMIME: "image/svg+xml")], background: SlideBackground(imageData: attack, imageMIME: "image/svg+xml"))])
        #expect(EmbeddedImage.dataURL(data: attack, mime: "image/svg+xml") == nil)
        // Raw document image bytes deliberately bypass native import here.
        for html in [HTMLRenderer.preview(deck: deck, slideIndex: 0), HTMLRenderer.export(deck: deck)] {
            #expect(!html.contains("src=\"data:image/svg+xml;base64,"))
            #expect(!html.contains("example.invalid/tracker"))
            #expect(!html.contains("bad()"))
        }
    }

    @Test func rasterEmbeddingRetainsItsPreviousMIMEAndBytes() {
        let bytes = Data([0, 12, 100, 255])
        for mime in ["image/png", "image/jpeg", "image/gif", "image/webp", "image/tiff"] {
            #expect(EmbeddedImage.isSupported(data: bytes, mime: mime))
            #expect(EmbeddedImage.dataURL(data: bytes, mime: mime) == "data:\(mime);base64,\(bytes.base64EncodedString())")
        }
    }
}
