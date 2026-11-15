import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SwiftRevealCore

struct EditorView: View {
    @Binding var document: PresentationDocument
    @State private var selectedSlideID: UUID?
    @State private var selectedBlockID: UUID?
    @State private var warnings: [String] = []
    @State private var errorMessage: String?
    @State private var exporting = false
    @State private var showDeckSettings = false
    @State private var showStyleEditor = false
    @State private var showDiagnostics = false

    private var slideIndex: Int {
        document.deck.slides.firstIndex { $0.id == selectedSlideID } ?? 0
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 218, max: 280)
        } detail: {
            HSplitView {
                canvas.frame(minWidth: 490, maxWidth: .infinity, maxHeight: .infinity)
                if !document.deck.slides.isEmpty {
                    SlideInspector(slide: slideBinding, selectedBlockID: $selectedBlockID, theme: document.deck.theme)
                        .frame(minWidth: 310, idealWidth: 350, maxWidth: 410, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle(document.deck.title)
        .toolbar { toolbar }
        .onAppear {
            if selectedSlideID == nil { selectedSlideID = document.deck.slides.first?.id }
            InteractionDiagnostics.shared.start()
        }
        .onChange(of: selectedSlideID) { _, _ in warnings = []; selectedBlockID = nil }
        .onChange(of: document.deck.slides.map(\.id)) { _, ids in
            if !ids.contains(selectedSlideID ?? UUID()) { selectedSlideID = ids.first }
        }
        .alert("SwiftReveal", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .sheet(isPresented: $showDeckSettings) { deckSettings }
        .sheet(isPresented: $showDiagnostics) { InteractionDiagnosticsView() }
        .sheet(isPresented: $showStyleEditor) { DeckStyleEditor(deck: $document.deck) }
        .disabled(exporting)
        .overlay { if exporting { ProgressView("Exporting presentation…").padding(28).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
    }

    private var slideBinding: Binding<Slide> {
        let id = document.deck.slides[slideIndex].id
        return Binding(get: { document.deck.slides.first { $0.id == id } ?? Slide() }, set: { value in
            guard let index = document.deck.slides.firstIndex(where: { $0.id == id }) else { return }
            document.deck.slides[index] = value
        })
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SLIDES").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(document.deck.slides.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            List(selection: $selectedSlideID) {
                ForEach(Array(document.deck.slides.enumerated()), id: \.element.id) { index, slide in
                    SlideRow(deck: document.deck, index: index)
                        .tag(slide.id)
                        .contextMenu {
                            Button("Duplicate slide") { duplicate(id: slide.id) }
                            Button("Move up") { move(id: slide.id, delta: -1) }.disabled(index == 0)
                            Button("Move down") { move(id: slide.id, delta: 1) }.disabled(index == document.deck.slides.count - 1)
                            Divider()
                            Button("Delete slide", role: .destructive) { delete(id: slide.id) }.disabled(document.deck.slides.count <= 1)
                        }
                }
                .onMove { source, destination in document.deck.slides.move(fromOffsets: source, toOffset: destination) }
            }
            .listStyle(.sidebar)
            Divider()
            HStack {
                InsertionPicker(title: "Add slide", symbol: "plus", choices: SlideLayout.allCases, label: { $0.label }, action: add)
                Spacer()
                Button { delete(id: document.deck.slides[slideIndex].id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless).help("Delete selected slide").disabled(document.deck.slides.count <= 1)
            }.padding(12)
        }
    }

    private var canvas: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(slideIndex + 1) / \(document.deck.slides.count)").monospacedDigit()
                Text("·")
                Text(document.deck.slides[slideIndex].layout.label)
                Spacer()
                Text("16:9 · 1280 × 720")
            }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 14)
            SlideWebPreview(deck: document.deck, slideIndex: slideIndex, onWarnings: { warnings = $0 }, onSelectBlock: { selectedBlockID = $0 })
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .padding(.horizontal, 20)
                .accessibilityLabel("Live slide preview")
            VStack(alignment: .leading, spacing: 7) {
                if warnings.isEmpty {
                    Label("Click a block to edit. Layout and spacing are automatic.", systemImage: "cursorarrow.rays")
                        .foregroundStyle(.secondary)
                } else {
                    Label("Content needs more room", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in Text(warning).foregroundStyle(.secondary) }
                    Text("Try compact spacing, a different layout, or move a block to a new slide.").foregroundStyle(.secondary)
                }
            }.font(.caption).frame(maxWidth: .infinity, alignment: .leading).padding(22)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            InsertionPicker(title: "Add slide", symbol: "plus.rectangle", choices: SlideLayout.allCases, label: { $0.label }, action: add)
                .help("Add a slide with a ready-made layout")
            Button { duplicate(id: document.deck.slides[slideIndex].id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }.help("Duplicate selected slide")
            Button { moveSelectedBlockToNewSlide() } label: { Label("Split slide", systemImage: "rectangle.split.2x1") }
                .help("Move the selected block to a new slide").disabled(selectedBlockID == nil)
            Button { showDeckSettings = true } label: { Label("Deck settings", systemImage: "paintpalette") }.help("Presentation title, theme and footer")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { showDiagnostics = true } label: { Label("Diagnostics", systemImage: "stethoscope") }
                .help("Inspect app, menu and window state")
            Button { showStyleEditor = true } label: { Label("CSS & themes", systemImage: "curlybraces") }.help("Edit deck CSS and save a reusable theme")
            Button { PresentationController.shared.present(deck: document.deck, startIndex: slideIndex) } label: { Label("Present", systemImage: "play.fill") }
            Menu {
                Button("Export PDF…") { exportPDF() }
                Button("Export HTML…") { exportHTML() }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
        }
    }

    private var deckSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Presentation settings").font(.title2.bold())
            Form {
                TextField("Title", text: $document.deck.title)
                TextField("Author", text: $document.deck.author)
                TextField("Footer", text: $document.deck.footer)
                Picker("Theme", selection: $document.deck.theme) { ForEach(DeckTheme.allCases, id: \.self) { Text($0.label).tag($0) } }
            }.formStyle(.grouped)
            Text("Theme changes apply to every slide. Your content and layout choices are preserved.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Done") { showDeckSettings = false }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 460)
    }

    private func add(_ layout: SlideLayout) {
        let slide = Slide.starter(layout)
        document.deck.slides.insert(slide, at: min(slideIndex + 1, document.deck.slides.count))
        selectedSlideID = slide.id
    }
    private func duplicate(id: UUID) {
        guard let index = document.deck.slides.firstIndex(where: { $0.id == id }) else { return }
        let copy = document.deck.slides[index].duplicated()
        document.deck.slides.insert(copy, at: index + 1); selectedSlideID = copy.id
    }
    private func delete(id: UUID) {
        guard document.deck.slides.count > 1, let index = document.deck.slides.firstIndex(where: { $0.id == id }) else { return }
        document.deck.slides.remove(at: index)
        selectedSlideID = document.deck.slides[min(index, document.deck.slides.count - 1)].id
    }
    private func move(id: UUID, delta: Int) {
        guard let index = document.deck.slides.firstIndex(where: { $0.id == id }), document.deck.slides.indices.contains(index + delta) else { return }
        document.deck.slides.swapAt(index, index + delta)
    }
    private func moveSelectedBlockToNewSlide() {
        let index = slideIndex
        guard let blockIndex = document.deck.slides[index].blocks.firstIndex(where: { $0.id == selectedBlockID }) else { return }
        let block = document.deck.slides[index].blocks.remove(at: blockIndex)
        let layout: SlideLayout = (block.kind == .figure || block.kind == .mermaid) ? .figure : block.kind == .table ? .table : .statement
        let slide = Slide(layout: layout, kicker: document.deck.slides[index].kicker,
                          title: document.deck.slides[index].title, density: document.deck.slides[index].density, blocks: [block],
                          background: document.deck.slides[index].background, fontScale: document.deck.slides[index].fontScale)
        document.deck.slides.insert(slide, at: index + 1)
        selectedSlideID = slide.id
    }
    private func destination(extension ext: String, type: UTType) -> URL? {
        let panel = NSSavePanel(); panel.allowedContentTypes = [type]
        let name = document.deck.title.isEmpty ? "Presentation" : document.deck.title.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(name).\(ext)"; panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
    private func exportHTML() {
        guard let url = destination(extension: "html", type: .html) else { return }
        do { try HTMLRenderer.export(deck: document.deck).write(to: url, atomically: true, encoding: .utf8) }
        catch { errorMessage = "HTML export failed: \(error.localizedDescription)" }
    }
    private func exportPDF() {
        guard let url = destination(extension: "pdf", type: .pdf) else { return }
        exporting = true
        let deck = document.deck
        Task { @MainActor in
            defer { exporting = false }
            do { try await PDFExporter().export(deck: deck, to: url) }
            catch { errorMessage = "PDF export failed: \(error.localizedDescription)" }
        }
    }
}

private struct SlideRow: View {
    let deck: Deck
    let index: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            SlideThumbnail(deck: deck, index: index)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Text("\(index + 1)").monospacedDigit()
                Text(deck.slides[index].layout.label).lineLimit(1)
            }.font(.caption2).foregroundStyle(.secondary)
        }.padding(.vertical, 5)
    }
}
