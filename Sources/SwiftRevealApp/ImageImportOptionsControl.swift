import SwiftUI

struct ImageImportOptionsControl: View {
    @Binding var preset: RasterImageOptimizer.Preset
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            InsertionPicker(title: "Import: " + (preset == .original ? "Original" : preset.label), symbol: "slider.horizontal.3",
                            choices: RasterImageOptimizer.Preset.allCases, label: { $0.label }) { preset = $0 }
                .accessibilityLabel("Import quality")
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var detail: String {
        if let limit = preset.maximumPixelSize {
            return "Next import: longest edge ≤ \(limit) px. JPEG/PNG below this limit keep their original bytes. SVG is unchanged."
        }
        return "Next import: preserve JPEG/PNG pixels and bytes. PDF/TIFF still use raster conversion. SVG is unchanged."
    }
}
