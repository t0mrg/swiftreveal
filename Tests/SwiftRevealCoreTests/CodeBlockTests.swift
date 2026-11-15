import Foundation
import Testing
@testable import SwiftRevealCore

struct CodeBlockTests {
    private func literalCode(_ html: String) -> String {
        guard let start = html.range(of: #"<pre class="sr-code"><code(?: class="[^"]*")?>"#, options: .regularExpression),
              let end = html.range(of: "</code></pre>", range: start.upperBound..<html.endIndex) else { return "[missing code]" }
        return String(html[start.upperBound..<end.lowerBound])
            .replacingOccurrences(of: #"</?span(?: class="[^"]*")?>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    @Test func fencedCodePreservesBlankLinesSpacesTabsAndLiteralMarkup() {
        let code = "def report(values):\n\t# Keep the indentation\n    text = \"<script>**literal**</script> &amp;\"\n\n    return text + str(values[0])\n"
        let html = RichText.body("Before **code**\n```python\n" + code + "```\nAfter *code*")
        #expect(literalCode(html) == code)
        #expect(html.hasPrefix("<p>Before <strong>code</strong></p>"))
        #expect(html.hasSuffix("<p>After <em>code</em></p>"))
        #expect(html.contains("class=\"language-python\""))
        #expect(html.contains("sr-token-keyword\">def</span>"))
        #expect(html.contains("sr-token-comment"))
        #expect(html.contains("sr-token-string"))
        #expect(!html.contains("<script>"))
        #expect(!html.contains("<strong>literal</strong>"))
    }

    @Test func fencesSupportAliasesTildesAndLongDelimiters() {
        let code = "const html = `<b>hello</b>`;\n```\n"
        let html = RichText.body("````js\n" + code + "````")
        #expect(literalCode(html) == code)
        #expect(html.contains("language-javascript"))
        #expect(html.contains("sr-token-keyword\">const</span>"))
        #expect(literalCode(RichText.body("~~~text\n  first\n\n\tlast\n~~~")) == "  first\n\n\tlast\n")
        #expect(literalCode(RichText.body("  ```py\n  if True:\n      pass\n  ```")) == "if True:\n    pass\n")
    }

    @Test func unterminatedAndUnknownLanguageFencesStayLiteralAndSafe() {
        let source = "<img src=x onerror=alert(1)>\n  &copy; **not bold**"
        let html = RichText.body("```unknown\n" + source)
        #expect(literalCode(html) == source)
        #expect(html.contains("language-unknown"))
        #expect(!html.contains("sr-token-"))
        #expect(!html.contains("<img"))
        #expect(!html.contains("<strong>"))
        let plain = RichText.body("```plaintext\nif (true) return 42; # comment\n```")
        #expect(!plain.contains("sr-token-"))
        #expect(literalCode(plain) == "if (true) return 42; # comment\n")
        let attack = RichText.body("```python\"onmouseover=evil()\n<script>alert(1)</script>\n```")
        #expect(!attack.contains("class=\"language-"))
        #expect(!attack.contains("<script"))
        #expect(!attack.contains("onmouseover="))
    }

    @Test func markupAndMarkdownInsideCodeAreShownExactlyOnceDecoded() {
        let source = "&lt;em&gt; &amp; &#39; &alpha; <em>raw</em> `x` **y** _z_"
        #expect(literalCode(RichText.body("```\n" + source + "\n```")) == source + "\n")
        #expect(RichText.inline("`&amp; <b>x</b>`") == "<code>&amp;amp; &lt;b&gt;x&lt;/b&gt;</code>")
        #expect(!RichText.body("<script>\n```python\nsecret()\n```\n</script>Visible").contains("secret"))
        #expect(!RichText.body("<pre>\n```python\npass\n```\n</pre>").contains("sr-code"))
    }

    @Test func representativeLanguagesHighlightWithoutChangingTheCode() {
        let samples: [(String, String, String)] = [
            ("r", "# estimate\nif (TRUE) {\n  fit <- lm(y ~ x, data = d)\n}\n", "if"),
            ("sql", "SELECT COUNT(*) FROM records WHERE value > 1; -- sample\n", "SELECT"),
            ("swift", "let value = 2\nprint(\"value: \\(value)\")\n", "let"),
            ("json", "{\"enabled\": true, \"count\": 12}\n", "true"),
            ("bash", "# run\nif test -f data.csv; then\n  echo \"$HOME\"\nfi\n", "if"),
            ("html", "<!-- example -->\n<div class=\"sample\">text</div>\n", "&lt;div")
        ]
        for (language, source, highlighted) in samples {
            let html = RichText.body("```" + language + "\n" + source + "```")
            #expect(literalCode(html) == source)
            #expect(html.contains("sr-token-keyword\">" + highlighted))
        }
    }

    @Test func lineEndingsAreNormalizedAndFencesCanFollowLists() {
        let html = RichText.body("- First\r\n- Second\r\n```python\r\nx = 1\r\n\r\n  y = 2\r\n```\r\n- Third")
        #expect(literalCode(html) == "x = 1\n\n  y = 2\n")
        #expect(html.hasPrefix("<ul><li>First</li><li>Second</li></ul><pre"))
        #expect(html.hasSuffix("<ul><li>Third</li></ul>"))
        #expect(!html.contains("<p><pre"))
    }
}
