import AppKit
import Foundation

enum AliasCreationError: Error {
    case invalidArguments
    case failedToSetIcon(String)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("usage: create_alias_with_icon.swift <target_path> <output_path>\n", stderr)
    throw AliasCreationError.invalidArguments
}

let targetPath = arguments[1]
let outputPath = arguments[2]
let outputURL = URL(fileURLWithPath: outputPath)
let targetURL = URL(fileURLWithPath: targetPath, isDirectory: true)

try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let bookmarkData = try targetURL.bookmarkData(
    options: [.suitableForBookmarkFile],
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)

try URL.writeBookmarkData(bookmarkData, to: outputURL)

let targetIcon = NSWorkspace.shared.icon(forFile: targetPath)
let didSetIcon = NSWorkspace.shared.setIcon(targetIcon, forFile: outputPath, options: [])
if !didSetIcon {
    throw AliasCreationError.failedToSetIcon(outputPath)
}
