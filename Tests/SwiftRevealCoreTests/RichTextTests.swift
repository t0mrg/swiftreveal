import Foundation
import Testing
@testable import SwiftRevealCore

struct RichTextTests {
    @Test func safeHTMLAndMarkdownCanBeMixed() {
        let html = RichText.body("**Markdown** with <em>HTML</em> and H<sub>2</sub>O.\n- First <strong>point</strong>\n- Second *point*")
        #expect(html.contains("<strong>Markdown</strong> with <em>HTML</em> and H<sub>2</sub>O."))
        #expect(html.contains("<ul><li>First <strong>point</strong></li><li>Second <em>point</em></li></ul>"))
    }

    @Test func markdownEmphasisCanSpanSafeInlineHTML() {
        #expect(RichText.inline("**bold <em>mixed</em> tail**") == "<strong>bold <em>mixed</em> tail</strong>")
        #expect(RichText.inline("*hello <span class='emphasis'>there</span>*") == "<em>hello <span class=\"emphasis\">there</span></em>")
        #expect(RichText.inline("<span title='**attribute**'>plain</span>") == "<span title=\"**attribute**\">plain</span>")
        #expect(RichText.inline("\u{E000}\u{E001}0\u{E002} **safe**") == "\u{E000}\u{E001}0\u{E002} <strong>safe</strong>")
    }

    @Test func scriptAndEmbeddedContentAreRemovedRatherThanExecutedOrDisplayed() {
        let source = "Before<script>alert('secret')</script><iframe src='https://bad.invalid'>hidden</iframe><svg><script>bad()</script><text>hidden svg</text></svg><form><input value=x>hidden form</form>After"
        #expect(RichText.inline(source) == "BeforeAfter")
        let output = RichText.body(source)
        for prohibited in ["<script", "alert", "secret", "iframe", "hidden", "svg", "input", "form", "bad.invalid"] { #expect(!output.contains(prohibited)) }
    }

    @Test func untrustedAttributesAndExternalResourcesAreDiscarded() {
        let html = RichText.inline("<span CLASS='good bad_class' onclick='evil()' style='background:url(https://bad.invalid)' data-block-id='fake'>Safe</span><img src=x onerror=evil()><a href='javascript:alert(1)' onmouseover='evil()'>label</a>")
        #expect(html == "<span class=\"good bad_class\">Safe</span><a>label</a>")
        for prohibited in ["onclick", "style=", "data-", "<img", "href=", "bad.invalid", "javascript", "evil"] { #expect(!html.contains(prohibited)) }
    }

    @Test func malformedAndObfuscatedPayloadsCannotEscapeTheAllowlist() {
        let attacks = [
            "<ScRiPt/X>alert(1)</ScRiPt><b>Visible</b>",
            "<svg/onload=alert(1)><foreignObject><p>Hidden</p></foreignObject></svg>",
            "<img/src=x/onerror=alert(1)><b on&#x6c;oad=bad()>Visible</b>",
            "<!-- <script>secret</script> --><em>Visible</em>",
            "<span title='\"><script>bad()</script>'>Visible</span>",
            "<style>body{background:url(https://bad.invalid)}</style><p>Visible</p>",
            "<template><img src=x><script>bad()</script></template>Visible",
            "<script/>bad()"
        ]
        for source in attacks {
            let html = RichText.body(source)
            #expect(!html.contains("<script"))
            #expect(!html.contains("<svg"))
            #expect(!html.contains("<img"))
            #expect(!html.contains("<style"))
            #expect(!html.contains("<template"))
            #expect(!html.contains(" onload="))
            #expect(!html.contains(" onerror="))
            #expect(!html.contains(" on&#"))
        }
    }

    @Test func entitiesAndScientificComparisonsRemainReadable() {
        let html = RichText.inline("p < 0.05 & n > 10; &alpha; &le; &#8804; &lt;b&gt; &amp; \"quoted\"")
        #expect(html == "p &lt; 0.05 &amp; n &gt; 10; &alpha; &le; &#8804; &lt;b&gt; &amp; &quot;quoted&quot;")
        #expect(!RichText.inline("&lt;script&gt;alert(1)&lt;/script&gt;").contains("<script>"))
    }

    @Test func blockHTMLIsRetainedOnlyInBodyAndCodeDoesNotExecuteHTML() {
        let table = "<table class='evidence'><thead><tr><th colspan='2'>Heading</th></tr></thead><tbody><tr><td>**A**</td><td>B</td></tr></tbody></table>"
        let body = RichText.body(table)
        #expect(body.hasPrefix("<table class=\"evidence\">"))
        #expect(body.contains("<th colspan=\"2\">Heading</th>"))
        #expect(body.contains("<td><strong>A</strong></td>"))
        #expect(!body.contains("<p><table"))
        let heading = RichText.inline("<div><strong>Heading</strong></div>")
        #expect(heading == "<strong>Heading</strong>")
        #expect(RichText.inline("`<script>example</script>`") == "<code>&lt;script&gt;example&lt;/script&gt;</code>")
        #expect(RichText.body("<pre>**literal**\n  indented</pre>") == "<pre>**literal**\n  indented</pre>")
    }

    @Test func attributesAreReconstructedAndTagsAreBalanced() {
        let html = RichText.body("<table><tr><td colspan='99999' rowspan='2' class='a \" bad'><em>A</td></tr></table>")
        #expect(!html.contains("colspan="))
        #expect(html.contains("rowspan=\"2\""))
        #expect(html.contains("class=\"a bad\""))
        #expect(html.contains("<em>A</em></td>"))
        #expect(!html.contains("<p><table"))
    }

    @Test func orderedListsAndEscapedMarkdownAreSupported() {
        #expect(RichText.body("1. First\n2. Second") == "<ol><li>First</li><li>Second</li></ol>")
        #expect(RichText.inline("\\*literal\\* and `**code**` and ~~old~~") == "*literal* and <code>**code**</code> and <del>old</del>")
        #expect(RichText.inline("S_net and study_id") == "S_net and study_id")
    }
}
