import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SwiftRevealCore

/// Edits semantic content and layout choices. No canvas coordinates are exposed.
struct SlideInspector: View {
    @Binding var slide: Slide
    @Binding var selectedBlockID: UUID?
    var theme: DeckTheme = .azure
    @State private var backgroundError: String?
    @State private var backgroundImportPreset: RasterImageOptimizer.Preset = .balanced

    private var selectedBlock: Binding<ContentBlock>? {
        guard let id = selectedBlockID,
              let original = slide.blocks.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { slide.blocks.first(where: { $0.id == id }) ?? original },
            set: { value in
                guard let index = slide.blocks.firstIndex(where: { $0.id == id }) else { return }
                slide.blocks[index] = value
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                inspectorSection("SLIDE") {
                    labeledField("Title", text: $slide.title, axis: .vertical)
                    labeledField("Section label", text: $slide.kicker)
                    labeledField("Subtitle", text: $slide.subtitle, axis: .vertical)
                }

                inspectorSection("LAYOUT") {
                    Picker("Composition", selection: $slide.layout) {
                        ForEach(SlideLayout.allCases, id: \.self) { layout in
                            Text(layout.label).tag(layout)
                        }
                    }
                    Picker("Spacing", selection: $slide.density) {
                        ForEach(SlideDensity.allCases, id: \.self) { density in
                            Text(density.label).tag(density)
                        }
                    }
                    if slide.layout == .title {
                        Toggle("Centre title horizontally", isOn: Binding(get: { slide.centerTitleHorizontally ?? false }, set: { slide.centerTitleHorizontally = $0 }))
                            .disabled(!slide.blocks.isEmpty)
                        Toggle("Centre title vertically", isOn: Binding(get: { slide.centerTitleVertically ?? false }, set: { slide.centerTitleVertically = $0 }))
                            .disabled(!slide.blocks.isEmpty)
                        Text(slide.blocks.isEmpty ? "Aligns the title, subtitle and section label as one group." : "Title alignment is available when there are no content blocks.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    FontScaleControl(title: "Slide font scale", value: $slide.fontScale)
                    Text("Scales all slide text together, including titles, captions, tables and footer.")
                        .font(.caption).foregroundStyle(.secondary)
                    if slide.layout == .twoColumns || slide.layout == .figureAndText {
                        HStack {
                            Text("Left column")
                            Spacer()
                            Text("\(Int(slide.split * 100))%")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: $slide.split, in: 0.25...0.75, step: 0.05)
                            .accessibilityLabel("Left column width")
                    }
                    Text("Changing layout keeps all your content. Reorder blocks to change their placement.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                backgroundControls

                inspectorSection("CONTENT BLOCKS") {
                    if slide.blocks.isEmpty {
                        Text("Add a block to start writing.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(Array(slide.blocks.enumerated()), id: \.element.id) { index, block in
                        blockRow(block, index: index)
                    }
                    HStack {
                        InsertionPicker(title: "Add block", symbol: "plus", choices: BlockKind.allCases, label: { $0.label }) { kind in
                            let block = ContentBlock.starter(kind)
                            slide.blocks.append(block)
                            selectedBlockID = block.id
                        }
                        Spacer()
                        if selectedBlock != nil {
                            Button(action: duplicateSelectedBlock) {
                                Image(systemName: "plus.square.on.square")
                            }
                            .help("Duplicate selected block")
                            .accessibilityLabel("Duplicate selected block")
                            Button(role: .destructive, action: deleteSelectedBlock) {
                                Image(systemName: "trash")
                            }
                            .help("Delete selected block")
                            .accessibilityLabel("Delete selected block")
                        }
                    }
                }

                if let binding = selectedBlock {
                    BlockContentEditor(block: binding, theme: theme, layout: slide.layout, backgroundTextColor: slide.background?.textColor)
                        .id(binding.wrappedValue.id)
                }

                inspectorSection("PRESENTER NOTES") {
                    TextEditor(text: $slide.notes)
                        .font(.body)
                        .frame(minHeight: 100, maxHeight: 180)
                        .padding(5)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        .accessibilityLabel("Presenter notes")
                    Text("Notes are visible to you in the editor and included in HTML presenter view.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(18)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear(perform: ensureSelection)
        .onChange(of: slide.id) { _, _ in ensureSelection() }
        .onChange(of: slide.blocks.map(\.id)) { _, _ in ensureSelection() }
        .alert("Could not import background", isPresented: Binding(get: { backgroundError != nil }, set: { if !$0 { backgroundError = nil } })) {
            Button("OK") { backgroundError = nil }
        } message: { Text(backgroundError ?? "The image could not be opened.") }
    }

    private var backgroundControls: some View {
        inspectorSection("SLIDE BACKGROUND") {
            ImageImportOptionsControl(preset: $backgroundImportPreset)
            if let background = slide.background {
                ImportedImagePreview(data: background.imageData, mime: background.imageMIME)
                    .frame(maxWidth: .infinity).frame(height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                if background.imageMIME == "image/svg+xml" {
                    Text("SVG · vector source embedded").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Button("Replace image…", action: chooseBackground)
                    Spacer()
                    Button("Remove", role: .destructive) { slide.background = nil }
                }
                Picker("Placement", selection: backgroundBinding(\.imageFit, fallback: false)) {
                    Text("Fill and crop").tag(false)
                    Text("Fit entire image").tag(true)
                }
                ColorPicker("Overlay colour", selection: backgroundColorBinding(\.overlayColor, fallback: "#102036"), supportsOpacity: false)
                HStack {
                    Text("Overlay strength")
                    Spacer()
                    Text("\(Int(displayOverlayOpacity * 100))%")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { displayOverlayOpacity }, set: { value in
                    guard var current = slide.background else { return }
                    current.overlayOpacity = value; slide.background = current
                }), in: 0...1, step: 0.05)
                    .accessibilityLabel("Background overlay strength")
                ColorPicker("Slide text colour", selection: backgroundColorBinding(\.textColor, fallback: "#FFFFFF"), supportsOpacity: false)
                Text("The overlay keeps text readable. Block colours can be changed separately below.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Choose background image…", systemImage: "photo.on.rectangle", action: chooseBackground)
                Text("Use the theme background, or embed an image for this slide.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var displayOverlayOpacity: Double {
        guard let value = slide.background?.overlayOpacity, value.isFinite else { return 0.45 }
        return min(1, max(0, value))
    }

    private func backgroundBinding<Value>(_ path: WritableKeyPath<SlideBackground, Value>, fallback: Value) -> Binding<Value> {
        Binding(get: { slide.background?[keyPath: path] ?? fallback }, set: { value in
            guard var background = slide.background else { return }
            background[keyPath: path] = value; slide.background = background
        })
    }

    private func backgroundColorBinding(_ path: WritableKeyPath<SlideBackground, String>, fallback: String) -> Binding<Color> {
        let value = backgroundBinding(path, fallback: fallback)
        return Binding(get: { Color(hex: value.wrappedValue) }, set: { value.wrappedValue = $0.srHex })
    }

    private func chooseBackground() {
        let panel = NSOpenPanel()
        panel.title = "Choose a slide background"
        panel.prompt = "Embed Background"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .pdf, .svg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let image = try FigureImport.load(from: url, options: .init(preset: backgroundImportPreset))
                if var background = slide.background {
                    background.imageData = image.data; background.imageMIME = image.mime; slide.background = background
                } else { slide.background = SlideBackground(imageData: image.data, imageMIME: image.mime) }
            } catch { backgroundError = error.localizedDescription }
        }
    }

    private func blockRow(_ block: ContentBlock, index: Int) -> some View {
        HStack(spacing: 8) {
            Button {
                selectedBlockID = block.id
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: symbol(for: block.kind))
                        .frame(width: 18)
                        .foregroundStyle(selectedBlockID == block.id ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.heading.isEmpty ? block.kind.label : block.heading)
                            .lineLimit(1)
                        Text("\(index + 1) · \(block.kind.label)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8).padding(.horizontal, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selectedBlockID == block.id ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select block \(index + 1): \(block.heading.isEmpty ? block.kind.label : block.heading)")
            VStack(spacing: 3) {
                Button { moveBlock(block.id, by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(index == 0)
                    .help("Move block up")
                    .accessibilityLabel("Move block \(index + 1) up")
                Button { moveBlock(block.id, by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(index == slide.blocks.count - 1)
                    .help("Move block down")
                    .accessibilityLabel("Move block \(index + 1) down")
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    private func ensureSelection() {
        if !slide.blocks.contains(where: { $0.id == selectedBlockID }) {
            selectedBlockID = slide.blocks.first?.id
        }
    }

    private func duplicateSelectedBlock() {
        guard let id = selectedBlockID,
              let index = slide.blocks.firstIndex(where: { $0.id == id }) else { return }
        var block = slide.blocks[index]
        block.id = UUID()
        slide.blocks.insert(block, at: index + 1)
        selectedBlockID = block.id
    }

    private func deleteSelectedBlock() {
        guard let id = selectedBlockID,
              let index = slide.blocks.firstIndex(where: { $0.id == id }) else { return }
        slide.blocks.remove(at: index)
        selectedBlockID = slide.blocks.isEmpty ? nil : slide.blocks[min(index, slide.blocks.count - 1)].id
    }

    private func moveBlock(_ id: UUID, by distance: Int) {
        guard let index = slide.blocks.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + distance
        guard slide.blocks.indices.contains(destination) else { return }
        slide.blocks.swapAt(index, destination)
    }

    private func symbol(for kind: BlockKind) -> String {
        switch kind {
        case .text: return "text.alignleft"
        case .callout: return "text.bubble"
        case .metric: return "number"
        case .figure: return "photo"
        case .table: return "tablecells"
        case .mermaid: return "point.3.connected.trianglepath.dotted"
        }
    }
}

private struct BlockContentEditor: View {
    @Binding var block: ContentBlock
    let theme: DeckTheme
    let layout: SlideLayout
    let backgroundTextColor: String?
    @State private var importError: String?
    @State private var figureImportPreset: RasterImageOptimizer.Preset = .balanced
    // Keep the editing buffer separate from parsed TSV. Otherwise pressing Return
    // at the end of a table would be undone immediately by whitespace normalization.
    @State private var tableDraft: String

    init(block: Binding<ContentBlock>, theme: DeckTheme, layout: SlideLayout, backgroundTextColor: String?) {
        _block = block
        self.theme = theme
        self.layout = layout
        self.backgroundTextColor = backgroundTextColor
        _tableDraft = State(initialValue: block.wrappedValue.table.tsv)
    }

    var body: some View {
        inspectorSection("EDIT \(block.kind.label.uppercased())") {
            labeledField(block.kind == .metric ? "Value" : "Heading", text: $block.heading, axis: .vertical)
            FontScaleControl(title: "Block font scale", value: $block.fontScale)
            Text("Relative to the slide scale. For example, 1.2 em here on a 1.1 em slide gives 1.32× text.")
                .font(.caption).foregroundStyle(.secondary)
            switch block.kind {
            case .text, .callout, .metric:
                Text(block.kind == .metric ? "Description" : "Body")
                    .font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $block.body)
                    .font(.body)
                    .frame(minHeight: block.kind == .metric ? 70 : 150, maxHeight: 260)
                    .padding(5)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .accessibilityLabel(block.kind == .metric ? "Metric description" : "Block body")
                if block.kind != .metric {
                    Text("Use Markdown or safe HTML, such as **bold**, <em>emphasis</em> and <sup>2</sup>. Start lines with - or • for bullets. Use fenced code blocks with a language, for example ```python, and a closing ``` on its own line.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .figure:
                figureControls
            case .table:
                tableControls
            case .mermaid:
                Text("Mermaid source").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $block.body)
                    .font(.system(size: 13, design: .monospaced))
                    .autocorrectionDisabled()
                    .frame(minHeight: 200, maxHeight: 360)
                    .padding(5)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    .accessibilityLabel("Mermaid diagram source")
                Text("Use flowchart LR or flowchart TD with arrows such as A[Input] --> B[Output]. Diagrams render as SVG. Invalid source shows an error in the preview.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            labeledField("Caption / source", text: $block.caption, axis: .vertical)
            Divider().padding(.vertical, 4)
            appearanceControls
        }
        .alert("Could not import figure", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "The image could not be opened.")
        }
        .onChange(of: tableDraft) { _, value in
            let parsed = TableData(tsv: value)
            if block.table != parsed { block.table = parsed }
        }
        .onChange(of: block.table) { _, value in
            // Accept undo/redo or external edits without disrupting an unfinished row.
            if TableData(tsv: tableDraft) != value { tableDraft = value.tsv }
        }
    }

    private var appearanceControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("BLOCK COLOURS").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button("Reset all") { block.style = nil }.font(.caption)
                    .disabled(block.style == nil)
            }
            ThemeColorControl(label: "Background", override: styleBinding(\.background), fallback: defaultBackground)
            ThemeColorControl(label: "Text", override: styleBinding(\.foreground), fallback: defaultForeground)
            ThemeColorControl(label: "Accent", override: styleBinding(\.accent), fallback: theme.palette.accent)
            if block.kind == .table {
                ThemeColorControl(label: "Header background", override: styleBinding(\.headerBackground), fallback: theme.palette.surface)
                ThemeColorControl(label: "Header text", override: styleBinding(\.headerForeground), fallback: theme.palette.secondary)
            }
            Text("Custom colours stay with this block when you change theme. Reset to use the theme again.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var defaultForeground: String {
        if let backgroundTextColor {
            if layout != .cards && (block.kind == .text || block.kind == .figure || block.kind == .mermaid) {
                return HexColor.normalized(backgroundTextColor) ?? "#FFFFFF"
            }
            return theme.palette.ink
        }
        return layout == .title ? "#FFFFFF" : theme.palette.ink
    }

    private var defaultBackground: String {
        if layout == .cards { return theme.palette.surface }
        switch block.kind {
        case .callout: return theme.palette.wash
        case .metric: return theme.palette.tint
        default: return theme.palette.surface
        }
    }

    private func styleBinding(_ path: WritableKeyPath<BlockStyle, String?>) -> Binding<String?> {
        Binding(get: { block.style?[keyPath: path] }, set: { value in
            var style = block.style ?? BlockStyle()
            style[keyPath: path] = value
            block.style = style == BlockStyle() ? nil : style
        })
    }

    private var figureControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ImageImportOptionsControl(preset: $figureImportPreset)
            if let data = block.imageData {
                ImportedImagePreview(data: data, mime: block.imageMIME)
                    .frame(maxWidth: .infinity).frame(height: 150)
                    .padding(8)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file) + (block.imageMIME == "image/svg+xml" ? " · SVG vector source embedded" : " · embedded in presentation"))
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("No figure selected", systemImage: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .background(Color.primary.opacity(0.035))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            HStack {
                Button(block.imageData == nil ? "Choose figure…" : "Replace figure…", action: chooseFigure)
                if block.imageData != nil {
                    Button("Remove", role: .destructive) { block.imageData = nil }
                }
            }
            Picker("Placement", selection: $block.imageFit) {
                Text("Fit entire figure").tag(true)
                Text("Fill and crop").tag(false)
            }
            Text("SVG, PNG, JPEG, TIFF or PDF, up to 20 MB. SVG stays vector; JPEG/PNG retain their format. TIFF and the first PDF page become PNG. Import quality applies to the next chosen image.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var tableControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Table data").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Paste from clipboard") {
                    if let text = NSPasteboard.general.string(forType: .string) {
                        tableDraft = text
                        block.table = TableData(tsv: text)
                    }
                }
                .help("Paste tab-separated cells copied from a spreadsheet")
            }
            TextEditor(text: $tableDraft)
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 180, maxHeight: 300)
                .padding(5)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .accessibilityLabel("Table data, tab separated with headers in the first row")
            Text("Paste cells copied from Excel or Numbers. The first row supplies headers, tabs separate columns, and each line makes a row.")
                .font(.caption).foregroundStyle(.secondary)
            Text("\(block.table.headers.count) columns · \(block.table.rows.count) data rows")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func chooseFigure() {
        let panel = NSOpenPanel()
        panel.title = "Choose a figure"
        panel.prompt = "Embed Figure"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .pdf, .svg]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let imported = try FigureImport.load(from: url, options: .init(preset: figureImportPreset))
                block.imageData = imported.data
                block.imageMIME = imported.mime
            } catch {
                importError = error.localizedDescription
            }
        }
    }
}

private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
        content()
    }
}

private func labeledField(_ label: String, text: Binding<String>, axis: Axis = .horizontal) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label).font(.caption).foregroundStyle(.secondary)
        TextField(label, text: text, axis: axis)
            .textFieldStyle(.roundedBorder)
            .lineLimit(axis == .vertical ? 1...5 : 1...1)
            .accessibilityLabel(label)
    }
}
