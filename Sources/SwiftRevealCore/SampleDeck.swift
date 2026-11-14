import Foundation

public extension Deck {
    /// A complete, editable introduction. The figures and scores are illustrative.
    static var sample: Deck {
        let image = CoreResources.url("example-figure", extension: "png").flatMap { try? Data(contentsOf: $0) }
        return Deck(title: "Clear ideas, beautifully arranged", author: "", footer: "SwiftReveal · Getting started", slides: [
            Slide(layout: .title, kicker: "SwiftReveal", title: "Clear ideas,\nbeautifully arranged", subtitle: "An easier way to make professional presentations on your Mac", notes: "Welcome to SwiftReveal. Every slide in this introduction is editable. Use the content inspector to replace this text, then explore the other layouts.", blocks: [
                ContentBlock(kind: .callout, heading: "Content first. Layout taken care of.", body: "Choose a structure, add your evidence, and let the slide handle the spacing.")
            ]),
            Slide(layout: .twoColumns, kicker: "A simpler workflow", title: "Spend your time on the message", subtitle: "Edit content and relationships instead of individual coordinates.", notes: "Click any content block in the preview to select it in the inspector. Standard Mac Save, Open, Undo and Redo work with your presentation document.", blocks: [
                ContentBlock(kind: .text, heading: "Start with the structure", body: "- Choose a slide layout from the inspector.\n- Edit the title, subtitle and content blocks.\n- Add or reorder blocks as your story changes.\n- Switch themes for the entire presentation."),
                ContentBlock(kind: .callout, heading: "Consistent by construction", body: "Shared margins, type sizes and spacing keep your deck coherent.\n**Click this box** to select its content in the inspector.", caption: "Tip: use **double asterisks** for emphasis and - for bullets.")
            ]),
            Slide(layout: .cards, kicker: "Reusable components", title: "Useful structures, ready to edit", notes: "Add another block and the grid recomputes its rows. If content does not fit, the app warns you rather than silently reducing the type size.", blocks: [
                ContentBlock(kind: .callout, heading: "Text and callouts", body: "Explain the main finding, or give a conclusion a little more emphasis."),
                ContentBlock(kind: .callout, heading: "Figures and captions", body: "Import a chart or image. Keep its proportions, or crop it to fill the space."),
                ContentBlock(kind: .callout, heading: "Tables from your data", body: "Paste tab-separated cells. The first row becomes the column headings."),
                ContentBlock(kind: .callout, heading: "A measured fit", body: "Use the overflow feedback to choose a more suitable layout or split a dense slide.")
            ]),
            Slide(layout: .metrics, kicker: "At a glance", title: "A few numbers, given room to breathe", subtitle: "Large figures and clear labels work better than a crowded paragraph.", notes: "These are product features, not research findings. Metric blocks are regular editable content blocks.", blocks: [
                ContentBlock(kind: .metric, heading: "8", body: "curated slide layouts", caption: "Title, text, figures, tables and more"),
                ContentBlock(kind: .metric, heading: "9", body: "coordinated themes", caption: "Light and dark palettes, with custom block colours"),
                ContentBlock(kind: .metric, heading: "0", body: "accounts required", caption: "Create and present entirely offline")
            ]),
            Slide(layout: .figureAndText, kicker: "Evidence and interpretation", title: "Keep the figure beside its explanation", subtitle: "The column split controls the relationship between the two areas.", notes: "This figure contains invented example values. Import your own plot using Choose Image in the figure block inspector. PNG and JPEG are suitable interchange formats. Your image is embedded in the presentation file.", split: 0.6, blocks: [
                ContentBlock(kind: .figure, caption: "Illustrative estimates only. Replace with your own figure and source.", imageData: image),
                ContentBlock(kind: .text, heading: "Make the evidence readable", body: "- Give the figure enough room.\n- State what the audience should look for.\n- Keep the source with the figure.\n- Use the inspector to change the column split.")
            ]),
            Slide(layout: .table, kicker: "Structured evidence", title: "Tables that belong to the slide", subtitle: "Paste a rectangular selection from Excel or another spreadsheet.", notes: "These rows describe the example app. The first line of tab-separated input becomes the header. All rows remain in the document, even if the table is too tall for the slide.", blocks: [
                ContentBlock(kind: .table, caption: "Table text stays editable. No screenshot required.", table: TableData(headers: ["Content", "How you edit it", "What stays consistent"], rows: [
                    ["Main message", "Title and subtitle fields", "Hierarchy and margins"],
                    ["Explanation", "Text or callout block", "Typography and padding"],
                    ["Figure", "Choose image + caption", "Proportions and alignment"],
                    ["Evidence table", "Tab-separated cells", "Row rules and spacing"],
                    ["Whole deck", "Theme and footer", "Colours and visual style"]
                ]))
            ]),
            Slide(layout: .figure, kicker: "A closer look", title: "Let a detailed figure use the full width", notes: "The same embedded image can be used in different layouts. Replacing the figure or changing its caption does not require repositioning a bounding box.", blocks: [
                ContentBlock(kind: .figure, caption: "Illustrative estimates only · Choose Fit to preserve the complete figure, or Fill to crop to the available area.", imageData: image)
            ]),
            Slide(layout: .statement, kicker: "Your next presentation", title: "Start with one clear idea", notes: "Create a new slide with the plus button, or replace this example deck with your own content. Present from the toolbar. Press N during presentation to show notes. Export HTML for an offline browser presentation, or PDF to share a static version.", blocks: [
                ContentBlock(kind: .text, body: "Choose a layout. Add the evidence.\nMake the message clear.", caption: "Save your editable document, then export HTML or PDF when you are ready.")
            ])
        ])
    }
}
