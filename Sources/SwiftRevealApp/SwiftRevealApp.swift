import SwiftUI
import UniformTypeIdentifiers
import SwiftRevealCore

extension UTType {
    static let swiftReveal = UTType(exportedAs: "org.swiftreveal.presentation", conformingTo: .data)
}

struct PresentationDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.swiftReveal] }
    var deck: Deck
    // Explicit Optimize marks a document dirty even when only lossless storage changes.
    var storageRevision = 0
    init(deck: Deck = .blank) { self.deck = deck }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        deck = try PresentationFile.decode(data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try PresentationFile.encode(deck))
    }
}

@main
struct SwiftRevealApp: App {
    init() {
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.async { Task { @MainActor in _ = await SmokeCheck.runIfRequested() } }
        }
    }
    var body: some Scene {
        DocumentGroup(newDocument: PresentationDocument()) { configuration in
            EditorView(document: configuration.$document)
                .frame(minWidth: 1080, minHeight: 700)
        }
        .defaultSize(width: 1460, height: 900)
        .commands {
            SlideTransferCommands()
            CommandGroup(replacing: .help) {
                Button("SwiftReveal Guide") { GuideWindow.show() }
                Divider()
                Button("Run Integration Checks…") { Task { @MainActor in await SmokeCheck.runInteractive() } }
            }
        }
    }
}

@MainActor
enum GuideWindow {
    static func show() {
        let alert = NSAlert()
        alert.messageText = "SwiftReveal · Structured slides"
        alert.informativeText = "Choose a slide on the left, then edit its content on the right. Click a block in the preview to select it.\n\nLayouts control alignment and spacing. Change layouts without losing content. Use the column split and density controls to adjust composition. If a slide is too full, shorten the content or move a block to a new slide.\n\nFigures are embedded in your document. For tables, paste tab-separated cells with a header row.\n\n⌘S saves your editable .swiftreveal document. Export produces a separate PDF or offline HTML presentation. In presentation mode, use arrow keys to navigate, S for notes and Esc to leave full screen.\n\nThis is a local testing build. PowerPoint import/export and arbitrary HTML import are not supported."
        alert.addButton(withTitle: "Got it")
        alert.runModal()
    }
}
