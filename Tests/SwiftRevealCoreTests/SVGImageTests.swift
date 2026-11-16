import Foundation
import Testing
@testable import SwiftRevealCore

struct SVGImageTests {
    private func wrapped(_ content: String, attributes: String = "") -> Data {
        Data("<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 400 240\" \(attributes)>\(content)</svg>".utf8)
    }
    private func sanitized(_ source: Data) throws -> String {
        String(decoding: try SVGImage.sanitize(source), as: UTF8.self)
    }

    @Test func matplotlibStyleExportKeepsVectorGlyphsStylesAndInternalUsesWithoutItsDTD() throws {
        let source = #"""
        <?xml version="1.0" encoding="utf-8" standalone="no"?>
        <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
        <svg xmlns:xlink="http://www.w3.org/1999/xlink" width="460.8pt" height="345.6pt" viewBox="0 0 460.8 345.6" xmlns="http://www.w3.org/2000/svg" version="1.1">
          <metadata><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description>Private creator metadata</rdf:Description></rdf:RDF></metadata>
          <defs><style type="text/css">*{stroke-linejoin: round; stroke-linecap: butt}</style><path id="m123" d="M 0 0 L 0 3.5" style="stroke: #000000; stroke-width: 0.8"/></defs>
          <g id="figure_1"><g id="axes_1"><path d="M 57.6 307.584 L 414.72 307.584" style="fill:none;stroke:#1f77b4;stroke-width:1.5"/><use xlink:href="#m123" x="73.832727" y="307.584" style="stroke:#000000;stroke-width:0.8"/><text x="100" y="320" style="font:10px 'DejaVu Sans';text-anchor:middle">Estimate &amp; uncertainty</text></g></g>
        </svg>
        """#
        let output = try sanitized(Data(source.utf8))
        #expect(!output.contains("DOCTYPE"))
        #expect(!output.contains("Private creator"))
        #expect(!output.contains("rdf:RDF"))
        #expect(output.contains("viewBox=\"0 0 460.8 345.6\""))
        #expect(output.contains("xlink:href=\"#m123\""))
        #expect(output.contains("stroke-linejoin:round;stroke-linecap:butt"))
        #expect(output.contains("Estimate &amp; uncertainty"))
        #expect(try SVGImage.sanitize(Data(output.utf8)) == Data(output.utf8))
    }

    @Test func cairoSymbolsAndInkscapeStaticFeaturesSurviveWithoutEditorMetadata() throws {
        let source = #"""
        <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" width="120mm" height="80mm" viewBox="0 0 120 80" inkscape:version="1.4" sodipodi:docname="private.svg">
        <sodipodi:namedview inkscape:document-units="mm"/>
        <defs>
          <symbol overflow="visible" id="glyph0-1" data-name="Letter A"><path style="stroke:none" d="M1 1L3 1L2 0Z"/></symbol>
          <linearGradient id="linear"><stop offset="0" stop-color="#1260A0"/><stop offset="1" stop-color="#40C0C0"/></linearGradient>
          <radialGradient id="radial" xlink:href="#linear" gradientTransform="matrix(1,0,0,1,0,0)"/>
          <clipPath id="clip"><rect width="100" height="70"/></clipPath>
          <mask id="mask"><rect width="100" height="70" fill="white"/></mask>
          <marker id="arrow" refX="8" refY="3" markerWidth="8" markerHeight="6" orient="auto"><path d="M0 0L8 3L0 6Z"/></marker>
          <filter id="shadow"><feGaussianBlur in="SourceAlpha" stdDeviation="1.5"/><feOffset dx="1" dy="2"/><feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
          <inkscape:path-effect effect="spiro"/>
        </defs>
        <style><![CDATA[.st0 { fill:url('#radial'); stroke:#102030; stroke-width:0.4; } text {font-family:'Noto Sans';font-size:4px;line-height:1.25;-inkscape-font-specification:'Noto Sans';}]]></style>
        <g clip-path="url(#clip)" mask="url(#mask)"><rect class="st0" width="100" height="70"/><path d="M10 10L90 10" marker-end="url(#arrow)" filter="url(#shadow)"/><use xlink:href="#glyph0-1" x="3" y="4"/><text xml:space="preserve" x="10" y="30">Δ = <tspan font-weight="bold">0.05</tspan></text></g>
        </svg>
        """#
        let output = try sanitized(Data(source.utf8))
        for tag in ["symbol", "linearGradient", "radialGradient", "clipPath", "mask", "marker", "filter", "feGaussianBlur", "feMergeNode", "tspan"] {
            #expect(output.contains("<" + tag))
        }
        #expect(output.contains("xlink:href=\"#glyph0-1\""))
        #expect(output.contains("Δ = "))
        #expect(output.contains("data-name=\"Letter A\""))
        #expect(output.contains("fill:url('#radial')"))
        #expect(!output.contains("sodipodi"))
        #expect(!output.contains("inkscape:version"))
        #expect(!output.contains("private.svg"))
        #expect(!output.contains("path-effect"))
        #expect(try SVGImage.sanitize(Data(output.utf8)) == Data(output.utf8))
    }

    @Test func embeddedRasterImagesMustBePNGsOrJPEGsWithMatchingMagicBytes() throws {
        for (mime, bytes) in [("image/png", Data([137, 80, 78, 71, 13, 10, 26, 10, 0, 0])), ("image/jpeg", Data([255, 216, 255, 224, 0, 0]))] {
            let uri = "data:\(mime);base64," + bytes.base64EncodedString()
            let output = try sanitized(wrapped("<image xlink:href=\"\(uri)\" width=\"40\" height=\"40\"/>"))
            #expect(output.contains(uri))
        }
        for uri in ["data:image/svg+xml;base64," + wrapped("<script>alert(1)</script>").base64EncodedString(),
                    "data:image/png;base64," + Data("<svg></svg>".utf8).base64EncodedString(),
                    "data:image/jpeg;base64,notbase64", "data:image/gif;base64,R0lGODlh"] {
            #expect(throws: (any Error).self) { try SVGImage.sanitize(wrapped("<image href=\"\(uri)\"/>")) }
        }
    }

    @Test func scriptsEventsAnimationForeignObjectsAndExternalReferencesAreRejected() {
        let attacks = [
            "<script>alert(1)</script>", "<g onclick=\"alert(1)\"><path d=\"M0 0\"/></g>",
            "<svg onload=\"alert(1)\"></svg>", "<foreignObject><div xmlns=\"http://www.w3.org/1999/xhtml\">HTML</div></foreignObject>",
            "<animate attributeName=\"href\" values=\"javascript:alert(1)\"/>", "<set attributeName=\"fill\" to=\"red\"/>",
            "<image href=\"https://example.invalid/image.png\"/>", "<image href=\"file:///private/file.png\"/>",
            "<use xlink:href=\"//example.invalid/file.svg#shape\"/>", "<use href=\"javascript:alert(1)\"/>",
            "<g xml:base=\"https://example.invalid/\"><use href=\"#shape\"/></g>",
            "<feImage href=\"data:image/svg+xml,%3Csvg%3E%3C/svg%3E\"/>",
            "<rect style=\"fill:url('https://example.invalid/paint.svg#p')\"/>",
            "<rect fill=\"uRl(//example.invalid/paint.svg#p)\"/>",
            "<rect style=\"fill:u/**/rl(https://example.invalid/p)\"/>",
            #"<rect style="fill:u\72l(https://example.invalid/p)"/>"#,
            "<rect style=\"fill:expression(alert(1))\"/>",
            "<style>@import url(https://example.invalid/style.css);</style>",
            "<style>@font-face{font-family:external;src:url(https://example.invalid/f.woff)}</style>",
            "<style>.x{fill:var(--resource)}</style>",
            "<style><![CDATA[.x{fill:url('data:image/svg+xml,<svg/>')}]]></style>",
            "<style>.x{behavior:url(#behavior)}</style>"
        ]
        for source in attacks { #expect(throws: (any Error).self) { try SVGImage.sanitize(wrapped(source)) } }
    }

    @Test func entityDeclarationsUnknownDTDsAndStylesheetInstructionsNeverResolve() {
        let attacks = [
            "<!DOCTYPE svg [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]><svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 10'><text>&xxe;</text></svg>",
            "<!DOCTYPE svg [<!ENTITY a 'aaaa'><!ENTITY b '&a;&a;&a;&a;'>]><svg viewBox='0 0 10 10'><text>&b;</text></svg>",
            "<!DOCTYPE svg SYSTEM 'https://example.invalid/evil.dtd'><svg viewBox='0 0 10 10'/>",
            "<?xml-stylesheet type='text/css' href='https://example.invalid/style.css'?><svg viewBox='0 0 10 10'/>",
            "<svg viewBox='0 0 10 10'><text>&unknown;</text></svg>"
        ]
        for source in attacks { #expect(throws: (any Error).self) { try SVGImage.sanitize(Data(source.utf8)) } }
    }

    @Test func malformedDocumentsDimensionsAndExcessiveComplexityFailClearly() throws {
        for source in ["<svg viewBox='0 0 10 10'><g></svg>", "<svg viewBox='0 0 -10 10'/>", "<svg viewBox='0 0 garbage 10 10'/>", "<svg width='100%' height='100%'/>", "<svg width='0' height='20'/>", "<svg/>", "<html viewBox='0 0 10 10'/>", "<svg viewBox='0 0 10 10' xmlns='https://example.invalid/svg'/>"] {
            #expect(throws: (any Error).self) { try SVGImage.sanitize(Data(source.utf8)) }
        }
        #expect(throws: SVGImageError.tooLarge) { try SVGImage.sanitize(Data(count: SVGImage.maximumBytes + 1)) }
        #expect(throws: SVGImageError.tooComplex) { try SVGImage.sanitize(wrapped(String(repeating: "<g>", count: 129) + String(repeating: "</g>", count: 129))) }
        #expect(try sanitized(Data("<svg width='80pt' height='40pt'><path d='M0 0L40 20'/></svg>".utf8)).contains("xmlns=\"http://www.w3.org/2000/svg\""))
        #expect(try sanitized(wrapped("<rect width='100' height='100'/>", attributes: "width='100%' height='100%' ")).contains("width=\"100%\""))
    }

    @Test func unicodeUTF16AndXMLTextArePreservedWithoutMarkupInjection() throws {
        let source = "<?xml version=\"1.0\" encoding=\"UTF-16\"?><svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\"><text xml:space=\"preserve\">日本語 Δ &amp; &lt;script&gt; &#945;</text></svg>"
        let utf16 = Data([0xFF, 0xFE]) + (try #require(source.data(using: .utf16LittleEndian)))
        let output = try sanitized(utf16)
        #expect(output.contains("日本語 Δ &amp; &lt;script&gt; α"))
        #expect(!output.contains("<script>"))
        #expect(output.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(try SVGImage.sanitize(Data(output.utf8)) == Data(output.utf8))
    }

    @Test func shippedSVGExamplesSanitizeWithoutLosingGradientAndTextContent() throws {
        let deck = try SVGExamples.deck()
        for slide in deck.slides {
            if let image = slide.background?.imageData, slide.background?.imageMIME == "image/svg+xml" { _ = try SVGImage.sanitize(image) }
            for block in slide.blocks where block.imageMIME == "image/svg+xml" {
                let image = try #require(block.imageData)
                #expect(try SVGImage.sanitize(image).count > 0)
            }
        }
    }
}
