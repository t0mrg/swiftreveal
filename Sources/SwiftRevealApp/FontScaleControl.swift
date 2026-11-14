import SwiftUI
import SwiftRevealCore

struct FontScaleControl: View {
    let title: String
    @Binding var value: Double?
    private var scale: Binding<Double> {
        Binding(get: { FontScaling.effective(value) }, set: { value = FontScaling.effective($0) })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                TextField("Font scale", value: scale, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder).frame(width: 64)
                    .accessibilityLabel(title)
                Text("em").font(.caption).foregroundStyle(.secondary)
                Button { value = nil } label: { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.borderless).help("Reset font scale to 1 em")
                    .accessibilityLabel("Reset \(title.lowercased())")
                    .disabled(value == nil || value == 1)
            }
            Slider(value: scale, in: FontScaling.range, step: 0.05).accessibilityLabel(title)
        }
    }
}
