import Foundation
import CryptoKit
import Testing
@testable import SwiftRevealCore

struct PowerPointRendererTests {
    @Test func exportRuntimeIsOfflineAndCSPTrusted() throws {
        let html = HTMLRenderer.powerPointSlide(deck: .blank, slideIndex: 0)
        let scripts = html.components(separatedBy: "<script>").dropFirst().compactMap { $0.components(separatedBy: "</script>").first }
        #expect(scripts.count == 3)
        for script in scripts {
            let hash = Data(SHA256.hash(data: Data(script.utf8))).base64EncodedString()
            #expect(html.contains("'sha256-\(hash)'"))
        }
        #expect(html.contains("swiftRevealPowerPoint="))
        #expect(html.contains("connect-src 'none'"))
        #expect(!html.contains("<script src="))
        #expect(!HTMLRenderer.singleSlide(deck: .blank, slideIndex: 0).contains("swiftRevealPowerPoint="))
    }

    @Test func customCSSAndMarkupRemainWithinTheirTrustBoundaries() {
        let deck = Deck(slides: [Slide(title: "<script>bad()</script>")], customCSS: "</style><script>evil()</script>", aspectRatio: .sixByFour)
        let html = HTMLRenderer.powerPointSlide(deck: deck, slideIndex: 0)
        #expect(!html.contains("<script>evil()"))
        #expect(!html.contains("<script>bad()"))
        #expect(html.contains("width:1296px;height:864px"))
    }
}
