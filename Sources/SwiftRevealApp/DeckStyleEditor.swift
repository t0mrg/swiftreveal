import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SwiftRevealCore

struct DeckStyleEditor: View {
    @Binding var deck: Deck
    @Environment(\.dismiss) private var dismiss
    @StateObject private var library = ThemeLibrary.shared
    @State private var themeName = ""
    @State private var previewIndex = 0
    @State private var warnings: [String] = []
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    private var css: Binding<String> {
        Binding(get: { deck.customCSS ?? "" }, set: { value in
            deck.customCSS = value.isEmpty ? nil : value
            savedMessage = nil
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Deck CSS & themes").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            HStack {
                Picker("Base theme", selection: $deck.theme) {
                    ForEach(DeckTheme.allCases, id: \.self) { Text($0.label).tag($0) }
                }.frame(width: 235)
                Menu("Apply saved theme") {
                    if library.themes.isEmpty { Text("No saved themes yet") }
                    ForEach(library.themes) { theme in
                        Button(theme.name) { apply(theme) }
                    }
                }.disabled(library.themes.isEmpty)
                Spacer()
                Button("Import theme…", action: importTheme)
                Button("Export theme…", action: exportTheme)
            }
            HSplitView {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("CUSTOM CSS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Menu("Insert example") {
                            Button("Callout styling") { appendCSS(Self.calloutExample) }
                            Button("Typography") { appendCSS(Self.typographyExample) }
                            Button("Theme palette") { appendCSS(Self.paletteExample) }
                        }.fixedSize()
                        Button("Reset CSS") { deck.customCSS = nil; deck.customThemeName = nil; savedMessage = nil }
                            .disabled((deck.customCSS ?? "").isEmpty)
                    }
                    TextEditor(text: css)
                        .font(.system(size: 12, design: .monospaced))
                        .disableAutocorrection(true)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                        .accessibilityLabel("Deck CSS source")
                    Text("CSS applies to every slide after the base theme. For proportional typography, use em units. External resources and scripts are blocked.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(minWidth: 390, idealWidth: 490)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("LIVE PREVIEW").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Picker("Slide", selection: $previewIndex) {
                            ForEach(Array(deck.slides.enumerated()), id: \.element.id) { index, slide in
                                Text("\(index + 1). \(slide.title.isEmpty ? "Untitled slide" : slide.title)").tag(index)
                            }
                        }.labelsHidden().frame(maxWidth: 240)
                    }
                    SlideWebPreview(deck: deck, slideIndex: min(previewIndex, max(0, deck.slides.count - 1)), onWarnings: { warnings = $0 }, onSelectBlock: { _ in })
                        .background(Color(nsColor: .underPageBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    if !warnings.isEmpty {
                        Label("The selected slide has content that may not fit.", systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Text("Useful selectors: .sr-slide, .sr-kicker, .sr-subtitle, .sr-heading, .sr-copy, .sr-caption, .block-callout, .block-table, th, td")
                        .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }.frame(minWidth: 390, idealWidth: 490)
            }
            Divider()
            HStack(spacing: 12) {
                TextField("New theme name", text: $themeName).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("New theme name")
                Button("Save as new theme", action: saveTheme)
                    .disabled(themeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let savedMessage {
                Label(savedMessage, systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Save a snapshot to reuse in other presentations. CSS is also stored inside this deck, so sharing the deck preserves its styling.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let warning = library.loadWarning { Text(warning).font(.caption).foregroundStyle(.orange) }
        }
        .padding(22)
        .frame(width: 1080, height: 740)
        .onAppear { library.reload(); themeName = deck.customThemeName ?? "" }
        .alert("Theme could not be saved or opened", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func apply(_ theme: SavedTheme) {
        deck = theme.applying(to: deck)
        themeName = theme.name
        savedMessage = "Applied \(theme.name). Further CSS edits affect this deck; the saved theme remains unchanged."
    }

    private func saveTheme() {
        do {
            let theme = try library.save(name: themeName, baseTheme: deck.theme, css: deck.customCSS ?? "")
            deck.customThemeName = theme.name
            savedMessage = "Saved \(theme.name). It is now available under Apply saved theme."
        } catch { errorMessage = error.localizedDescription }
    }

    private func appendCSS(_ example: String) {
        let existing = deck.customCSS ?? ""
        css.wrappedValue = existing + (existing.isEmpty ? "" : "\n\n") + example + "\n"
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.title = "Import a SwiftReveal theme"
        panel.allowedContentTypes = [.json, .data]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, (values.fileSize ?? Int.max) <= 2 * 1_024 * 1_024 else { throw ImportError.tooLarge }
            let theme = try SavedTheme.decode(Data(contentsOf: url))
            apply(theme)
            savedMessage = "Imported \(theme.name). Use Save as new theme to add it to your reusable themes."
        } catch { errorMessage = error.localizedDescription }
    }

    private func exportTheme() {
        let cleanName = themeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { errorMessage = ThemeError.emptyName.localizedDescription; return }
        let panel = NSSavePanel()
        panel.title = "Export a reusable theme"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = cleanName.replacingOccurrences(of: "/", with: "-") + ".swiftrevealtheme.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let theme = SavedTheme(name: cleanName, baseTheme: deck.theme, css: deck.customCSS ?? "")
            try theme.encoded().write(to: url, options: .atomic)
            savedMessage = "Exported \(cleanName) as a portable theme file."
        } catch { errorMessage = error.localizedDescription }
    }

    private enum ImportError: LocalizedError {
        case tooLarge
        var errorDescription: String? { "Choose a regular theme JSON file smaller than 2 MB." }
    }

    private static let calloutExample = """
    .sr-slide .block-callout {
      border-radius: 0.5em;
      border-left-width: 0.25em;
      background: #edf4fc;
    }
    .sr-slide .block-callout .sr-heading { color: #174d8f; }
    """
    private static let typographyExample = """
    .sr-slide { font-family: Georgia, serif; }
    .sr-slide .sr-heading { letter-spacing: 0.02em; }
    .sr-slide .sr-copy { line-height: 1.5; }
    """
    private static let paletteExample = """
    :root {
      --accent: #087f8c;
      --deep: #085b65;
      --wash: #e1f1f0;
    }
    """
}
