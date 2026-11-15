import AppKit
import SwiftUI
import UniformTypeIdentifiers
import SwiftRevealCore

extension UTType {
    static let swiftRevealSlides = UTType(exportedAs: "org.swiftreveal.slides", conformingTo: .json)
}

@MainActor enum SlideClipboard {
    static let type = NSPasteboard.PasteboardType(UTType.swiftRevealSlides.identifier)

    static func write(_ transfer: SlideTransfer) throws {
        let data = try transfer.encoded()
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setData(data, forType: type) else { throw ClipboardError.couldNotWrite }
    }

    static func read() throws -> SlideTransfer {
        guard let data = NSPasteboard.general.data(forType: type) else { throw ClipboardError.noSlides }
        return try SlideTransfer.decode(data)
    }

    static func provider(_ transfer: SlideTransfer) throws -> NSItemProvider {
        let data = try transfer.encoded()
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    static func read(from providers: [NSItemProvider]) async throws -> SlideTransfer {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type.rawValue) }) else { throw ClipboardError.noSlides }
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type.rawValue) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: ClipboardError.noSlides) }
            }
        }
        return try SlideTransfer.decode(data)
    }

    enum ClipboardError: LocalizedError {
        case noSlides, couldNotWrite
        var errorDescription: String? {
            switch self {
            case .noSlides: return "Copy slides from a SwiftReveal presentation first."
            case .couldNotWrite: return "Could not copy the selected slides to the clipboard."
            }
        }
    }
}

struct SlideTransferActions {
    let canCopy: Bool
    let copy: () -> Void
    let paste: () -> Void
}
private struct SlideTransferActionsKey: FocusedValueKey { typealias Value = SlideTransferActions }
extension FocusedValues {
    var slideTransferActions: SlideTransferActions? {
        get { self[SlideTransferActionsKey.self] }
        set { self[SlideTransferActionsKey.self] = newValue }
    }
}
struct SlideTransferCommands: Commands {
    @FocusedValue(\.slideTransferActions) private var actions
    var body: some Commands {
        CommandMenu("Slides") {
            Button("Copy selected slides") { actions?.copy() }
                .keyboardShortcut("c", modifiers: [.command, .option])
                .disabled(actions?.canCopy != true)
            Button("Paste slides above selection") { actions?.paste() }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(actions == nil)
        }
    }
}
