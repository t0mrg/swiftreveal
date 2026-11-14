import AppKit
import SwiftUI
import SwiftRevealCore

extension Color {
    init(hex: String) {
        let valid = HexColor.normalized(hex) ?? "#000000"
        let rgb = UInt32(valid.dropFirst(), radix: 16) ?? 0
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                  green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, opacity: 1)
    }

    var srHex: String {
        guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int((max(0, min(1, rgb.redComponent)) * 255).rounded())
        let g = Int((max(0, min(1, rgb.greenComponent)) * 255).rounded())
        let b = Int((max(0, min(1, rgb.blueComponent)) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

/// Choosing a colour creates an override; resetting restores theme inheritance.
struct ThemeColorControl: View {
    let label: String
    @Binding var override: String?
    let fallback: String

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker(label, selection: Binding(
                get: { Color(hex: override ?? fallback) },
                set: { override = $0.srHex }), supportsOpacity: false)
            Text(override == nil ? "Theme" : "Custom")
                .font(.caption2).foregroundStyle(.secondary).frame(width: 43)
            Button {
                override = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(override == nil)
            .help("Use theme colour for \(label.lowercased())")
            .accessibilityLabel("Reset \(label.lowercased()) to theme")
        }
    }
}
