import AppKit

/// Rendering must never participate in document focus, mouse input or menu routing.
@MainActor final class RenderHostPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(content: NSView) {
        super.init(contentRect: NSRect(x: -10000, y: -10000, width: content.frame.width, height: content.frame.height),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isFloatingPanel = false
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        isExcludedFromWindowsMenu = true
        isRestorable = false
        animationBehavior = .none
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        contentView = content
    }

    func prepareForRendering() {
        // Reordering on every thumbnail can interfere with an active menu session.
        if !isVisible { orderBack(nil) }
    }
}
