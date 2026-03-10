#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("usage: render_dmg_background.swift <output.png>\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]

let scale: CGFloat = 2
let logicalWidth: CGFloat = 560
let logicalHeight: CGFloat = 360
let pixelWidth = logicalWidth * scale
let pixelHeight = logicalHeight * scale

let image = NSImage(size: NSSize(width: pixelWidth, height: pixelHeight))

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("failed to acquire graphics context\n", stderr)
    exit(1)
}

context.scaleBy(x: scale, y: scale)

if let backgroundGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 0.984, green: 0.982, blue: 0.978, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.958, green: 0.955, blue: 0.949, alpha: 1).cgColor
    ] as CFArray,
    locations: [0.0, 1.0]
) {
    context.drawLinearGradient(
        backgroundGradient,
        start: CGPoint(x: 0, y: logicalHeight),
        end: CGPoint(x: 0, y: 0),
        options: []
    )
}

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)

