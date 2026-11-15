import Foundation

extension Deck {
    /// A compact, editable demonstration of alignment, Mermaid and fenced code.
    public static var formattingExamples: Deck {
        Deck(title: "Diagrams and code", footer: "SwiftReveal", slides: [
            Slide(layout: .title, title: "Diagrams and code", subtitle: "Structured layouts for technical presentations", centerTitleHorizontally: true, centerTitleVertically: true),
            Slide(layout: .figure, title: "A simple causal DAG", blocks: [
                ContentBlock(kind: .mermaid, body: """
                flowchart LR
                    C[Confounder] --> X[Exposure]
                    C --> Y[Outcome]
                    X --> Y
                """, caption: "Illustrative structure; arrows represent assumed causal relationships.")
            ]),
            Slide(layout: .twoColumns, title: "Code with its explanation", blocks: [
                ContentBlock(kind: .text, heading: "Python example", body: """
                ```python
                def mean(values):
                    if not values:
                        return None
                    return sum(values) / len(values)

                result = mean([10, 20, 30])
                print(result)
                ```
                """),
                ContentBlock(kind: .callout, heading: "Readable source", body: "Indentation and blank lines are preserved.\n\nUse a language after the opening fence to enable syntax highlighting.\n\nSlide and block font scales also apply to code.")
            ])
        ])
    }
}
