import Foundation
import SwiftRevealCore

// A headless developer utility: no AppKit or GUI session is needed.
let arguments = CommandLine.arguments
guard arguments.count == 3, arguments[1] == "generate-examples" else {
    FileHandle.standardError.write(Data("Usage: SwiftRevealTool generate-examples /absolute/output/directory\n".utf8))
    exit(2)
}
do {
    let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let deck = Deck.sample
    try deck.encoded().write(to: directory.appendingPathComponent("Getting-Started.swiftreveal"), options: .atomic)
    try HTMLRenderer.export(deck: deck).write(to: directory.appendingPathComponent("Getting-Started.html"), atomically: true, encoding: .utf8)
    print("Created editable sample and offline HTML in \(directory.path)")
} catch {
    FileHandle.standardError.write(Data("Example generation failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
