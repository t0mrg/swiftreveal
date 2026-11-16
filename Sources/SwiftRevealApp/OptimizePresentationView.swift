import SwiftUI
import SwiftRevealCore

struct OptimizePresentationView: View {
    @Binding var deck: Deck
    let apply: (Deck) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var preset: RasterImageOptimizer.Preset = .balanced
    @State private var compressPNG = false
    @State private var recompressJPEG = true
    @State private var working = false
    @State private var result: DeckOptimizationResult?
    @State private var errorMessage: String?
    @State private var analysisTask: Task<Void, Never>?
    @State private var generation = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Optimize presentation").font(.title2.bold())
                Spacer()
                Button("Cancel") { analysisTask?.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("Review estimated file sizes before changing image data. SVG images are preserved. Saving can also deduplicate repeated images and losslessly compress the document.")
                .font(.callout).foregroundStyle(.secondary)
            Picker("Image resolution", selection: $preset) {
                ForEach(RasterImageOptimizer.Preset.allCases) { Text($0 == .original ? "Original" : $0.label).tag($0) }
            }.pickerStyle(.segmented)
            Text(presetDetail).font(.caption).foregroundStyle(.secondary)
            Toggle("Recompress JPEG photos", isOn: $recompressJPEG).disabled(preset == .original)
            Toggle("Compress opaque PNG as JPEG (best for photos)", isOn: $compressPNG).disabled(preset == .original)
            Text("Leave PNG conversion off for charts, screenshots and crisp line art. Transparent output remains PNG. Lower resolution and JPEG quality can reduce detail; apply once after choosing your settings.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            if working {
                HStack { ProgressView().controlSize(.small); Text("Analyzing images and storage…") }.frame(height: 130)
            } else if let result {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow { Text("Legacy JSON size"); Text(bytes(result.before.legacyJSONBytes)).monospacedDigit() }
                    GridRow { Text("Next save, images unchanged"); Text(bytes(result.before.savedBytes)).monospacedDigit() }
                    GridRow { Text("After image optimization").bold(); Text(bytes(result.after.savedBytes)).bold().monospacedDigit() }
                    GridRow { Text("Reduction from legacy JSON"); Text(reduction(result)).monospacedDigit() }
                }
                Text("\(result.changedImageReferences) image uses changed · \(result.after.uniqueAssetCount) unique embedded images across \(result.after.imageReferenceCount) uses.")
                    .font(.caption).foregroundStyle(.secondary)
                if result.original != deck {
                    Text("The presentation changed. Analyze again before applying.").font(.caption).foregroundStyle(.orange)
                }
                if !result.warnings.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("These images will remain unchanged:").font(.caption.bold())
                            ForEach(Array(result.warnings.enumerated()), id: \.offset) { Text($0.element).font(.caption) }
                        }
                    }.frame(maxHeight: 80)
                }
            } else {
                Text("Choose settings and analyze to estimate the saved presentation size.")
                    .foregroundStyle(.secondary).frame(height: 100)
            }
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
            Text("Efficiently saved files require SwiftReveal 0.8 or later. Use Export → Editable JSON for a compatibility copy. Apply preserves slide content and supports Undo; save the document to write the smaller file.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Analyze", action: analyze).disabled(working)
                Spacer()
                Button("Apply optimization") {
                    guard let result, result.original == deck else { return }
                    apply(result.optimized)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(working || result == nil || result?.original != deck)
            }
        }
        .padding(24).frame(width: 630)
        .onAppear(perform: analyze)
        .onDisappear { analysisTask?.cancel() }
        .onChange(of: preset) { _, _ in invalidate() }
        .onChange(of: compressPNG) { _, _ in invalidate() }
        .onChange(of: recompressJPEG) { _, _ in invalidate() }
    }

    private var presetDetail: String {
        if let limit = preset.maximumPixelSize {
            return "Longest edge ≤ \(limit) pixels; JPEG quality \(Int(preset.jpegQuality * 100))%. Images are never enlarged."
        }
        return "Keep existing JPEG/PNG bytes unchanged. Only lossless document compression and asset deduplication apply."
    }
    private func bytes(_ count: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file) }
    private func reduction(_ result: DeckOptimizationResult) -> String {
        let original = result.before.legacyJSONBytes
        guard original > 0 else { return "0%" }
        return String(format: "%.1f%%", (1 - Double(result.after.savedBytes) / Double(original)) * 100)
    }
    private func invalidate() {
        generation = UUID(); analysisTask?.cancel(); working = false; result = nil; errorMessage = nil
    }
    private func analyze() {
        invalidate()
        let id = generation
        let original = deck
        let options = RasterImageOptimizer.Options(preset: preset, compressOpaquePNGAsJPEG: compressPNG, recompressJPEG: recompressJPEG)
        working = true
        analysisTask = Task { @MainActor in
            let worker = Task.detached(priority: .userInitiated) { try DeckRasterOptimizer.analyze(original, options: options) }
            do {
                let candidate = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
                try Task.checkCancellation()
                guard generation == id else { return }
                result = candidate; working = false
            } catch {
                guard generation == id, !Task.isCancelled else { return }
                errorMessage = error.localizedDescription; working = false
            }
        }
    }
}
