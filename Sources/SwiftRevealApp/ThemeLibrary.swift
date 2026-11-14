import Foundation
import SwiftUI
import SwiftRevealCore

/// Only this application's own saved themes are read. Every deck embeds its CSS.
@MainActor final class ThemeLibrary: ObservableObject {
    static let shared = ThemeLibrary()
    @Published private(set) var themes: [SavedTheme] = []
    @Published private(set) var loadWarning: String?

    private var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SwiftReveal", isDirectory: true)
            .appendingPathComponent("Themes", isDirectory: true)
    }

    private init() { reload() }

    func reload() {
        loadWarning = nil
        guard FileManager.default.fileExists(atPath: directory.path) else { themes = []; return }
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            var loaded: [SavedTheme] = []
            var failed = 0
            for url in urls where url.pathExtension == "json" {
                do {
                    guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
                    loaded.append(try SavedTheme.decode(Data(contentsOf: url)))
                } catch { failed += 1 }
            }
            themes = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if failed > 0 { loadWarning = "\(failed) saved theme file\(failed == 1 ? "" : "s") could not be read. The other themes are available." }
        } catch {
            loadWarning = "Saved themes could not be loaded: \(error.localizedDescription)"
        }
    }

    /// Saving always creates a new snapshot and does not modify an existing theme.
    func save(name: String, baseTheme: DeckTheme, css: String) throws -> SavedTheme {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw ThemeError.emptyName }
        guard !themes.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else {
            throw LibraryError.duplicateName
        }
        let theme = SavedTheme(name: cleanName, baseTheme: baseTheme, css: css)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try theme.encoded().write(to: directory.appendingPathComponent(theme.id.uuidString).appendingPathExtension("json"), options: .atomic)
        themes.append(theme)
        themes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return theme
    }

    enum LibraryError: LocalizedError {
        case duplicateName
        var errorDescription: String? { "A saved theme already has that name. Choose a different name to create a new theme." }
    }
}
