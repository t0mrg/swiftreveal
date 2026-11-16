import Foundation
import SwiftRevealCore

// A headless developer utility: no AppKit or GUI session is needed.
let arguments = CommandLine.arguments
guard arguments.count == 3, ["generate-examples", "measure-storage"].contains(arguments[1]) else {
    FileHandle.standardError.write(Data("Usage: SwiftRevealTool generate-examples /absolute/output/directory\n       SwiftRevealTool measure-storage /absolute/presentation.swiftreveal\n".utf8))
    exit(2)
}
do {
    if arguments[1] == "measure-storage" {
        let input = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
        let deck = try PresentationFile.decode(input)
        let encoded = try PresentationFile.encodeWithStatistics(deck)
        guard try PresentationFile.decode(encoded.data) == deck else { throw PresentationFileError.integrityCheckFailed }
        let stats = encoded.statistics
        let report: [String: Any] = ["inputBytes": input.count, "legacyJSONBytes": stats.legacyJSONBytes,
            "efficientFileBytes": stats.savedBytes, "bytesSaved": stats.bytesSaved,
            "percentSaved": stats.savingsFraction * 100, "uniqueAssets": stats.uniqueAssetCount,
            "imageReferences": stats.imageReferenceCount, "compressed": stats.isCompressed,
            "roundTripPreserved": true]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        exit(0)
    }
    let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let deck = Deck.sample
    try deck.encoded().write(to: directory.appendingPathComponent("Getting-Started.swiftreveal"), options: .atomic)
    try PresentationFile.encode(deck).write(to: directory.appendingPathComponent("Efficient-Storage.swiftreveal"), options: .atomic)
    try HTMLRenderer.export(deck: deck).write(to: directory.appendingPathComponent("Getting-Started.html"), atomically: true, encoding: .utf8)
    let formatting = Deck.formattingExamples
    try formatting.encoded().write(to: directory.appendingPathComponent("Diagrams-and-Code.swiftreveal"), options: .atomic)
    try HTMLRenderer.export(deck: formatting).write(to: directory.appendingPathComponent("Diagrams-and-Code.html"), atomically: true, encoding: .utf8)
    let vectors = try SVGExamples.deck()
    try vectors.encoded().write(to: directory.appendingPathComponent("SVG-Images.swiftreveal"), options: .atomic)
    try HTMLRenderer.export(deck: vectors).write(to: directory.appendingPathComponent("SVG-Images.html"), atomically: true, encoding: .utf8)
    try SVGExamples.figure.write(to: directory.appendingPathComponent("SVG-Figure.svg"), options: .atomic)
    try SVGExamples.background.write(to: directory.appendingPathComponent("SVG-Background.svg"), options: .atomic)
    print("Created editable sample and offline HTML in \(directory.path)")
} catch {
    FileHandle.standardError.write(Data("Example generation failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
