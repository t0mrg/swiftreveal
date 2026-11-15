import AppKit
import SwiftUI

/// Records application/window state only: no slide text, document names or keys.
@MainActor final class InteractionDiagnostics: ObservableObject {
    static let shared = InteractionDiagnostics()
    @Published private(set) var report = ""
    private var events: [[String: String]] = []
    private var observers: [NSObjectProtocol] = []
    private var started = false
    private(set) var lastWriteError: String?
    let reportURL = URL(fileURLWithPath: "/tmp/SwiftReveal-Diagnostics/menu-state.json")

    func start() {
        guard !started else { return }
        started = true
        let names: [Notification.Name] = [NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification, NSWindow.didBecomeKeyNotification,
            NSMenu.didBeginTrackingNotification, NSMenu.didEndTrackingNotification,
            NSMenu.didSendActionNotification]
        for name in names {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.capture(event: name.rawValue) }
            })
        }
        capture(event: "editorOpened")
    }

    func reconnectMenus() {
        capture(event: "beforeMenuReconnect")
        guard let menu = NSApp.mainMenu else { return }
        // Preserve SwiftUI's menu objects, delegates and action targets. Re-register
        // the existing main menu with AppKit rather than constructing another one.
        NSApp.mainMenu = nil
        NSApp.mainMenu = menu
        menu.update()
        capture(event: "afterMenuReconnect")
    }

    func capture(event: String = "manualSnapshot") {
        events.append(["event": event, "time": ISO8601DateFormatter().string(from: Date())])
        events = Array(events.suffix(60))
        let windows: [[String: Any]] = NSApp.windows.map { window in
            ["number": window.windowNumber, "class": String(describing: type(of: window)),
             "visible": window.isVisible, "key": window.isKeyWindow, "main": window.isMainWindow,
             "canBecomeKey": window.canBecomeKey, "canBecomeMain": window.canBecomeMain,
             "ignoresMouseEvents": window.ignoresMouseEvents,
             "renderHost": window is RenderHostPanel, "attachedSheet": window.attachedSheet != nil,
             "isSheet": window.sheetParent != nil]
        }
        let state: [String: Any] = [
            "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
            "active": NSApp.isActive, "activationPolicy": NSApp.activationPolicy().rawValue,
            "isRunning": NSApp.isRunning,
            "processIdentifier": ProcessInfo.processInfo.processIdentifier,
            "frontmostProcessIdentifier": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1,
            "menuBarOwnerProcessIdentifier": NSWorkspace.shared.menuBarOwningApplication?.processIdentifier ?? -1,
            "menuBarOwnerIsSwiftReveal": NSWorkspace.shared.menuBarOwningApplication?.bundleIdentifier == Bundle.main.bundleIdentifier,
            "mainMenuClass": NSApp.mainMenu.map { String(describing: type(of: $0)) } ?? "none",
            "menus": NSApp.mainMenu?.items.map { item -> [String: Any] in
                ["title": item.title, "enabled": item.isEnabled, "hidden": item.isHidden,
                 "hasSubmenu": item.submenu != nil, "itemCount": item.submenu?.numberOfItems ?? 0,
                 "submenuClass": item.submenu.map { String(describing: type(of: $0)) } ?? "none",
                 "hasDelegate": item.submenu?.delegate != nil]
            } ?? [],
            "hasMainMenu": NSApp.mainMenu != nil,
            "topLevelMenus": NSApp.mainMenu?.items.map(\.title) ?? [],
            "keyWindow": NSApp.keyWindow?.windowNumber ?? -1,
            "mainWindow": NSApp.mainWindow?.windowNumber ?? -1,
            "modalWindow": NSApp.modalWindow?.windowNumber ?? -1,
            "runLoopMode": RunLoop.current.currentMode?.rawValue ?? "none",
            "windows": windows, "events": events]
        do {
            let data = try JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys])
            report = String(decoding: data, as: UTF8.self)
            try FileManager.default.createDirectory(at: reportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: reportURL, options: .atomic)
            lastWriteError = nil
        } catch { lastWriteError = error.localizedDescription }
    }
}

struct InteractionDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var diagnostics = InteractionDiagnostics.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("App interaction diagnostics").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Text("This records menu tracking, activation and window state. Presentation content, document names and typed text are excluded.")
            ScrollView {
                Text(diagnostics.report).font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(10).background(Color(nsColor: .textBackgroundColor))
            HStack {
                Button("Refresh") { diagnostics.capture() }
                Button("Reconnect menu bar") { diagnostics.reconnectMenus() }
                Button("Copy report") {
                    diagnostics.capture()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(diagnostics.report, forType: .string)
                }
                Spacer()
            }
            if let error = diagnostics.lastWriteError {
                Text("Could not write report: \(error)").font(.caption).foregroundStyle(.red)
            } else {
                Text("Saved to \(diagnostics.reportURL.path)").font(.caption).textSelection(.enabled)
            }
        }
        .padding(22).frame(width: 740, height: 560)
        .onAppear { diagnostics.capture(event: "diagnosticsOpened") }
    }
}
