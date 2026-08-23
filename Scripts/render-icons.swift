#!/usr/bin/env swift
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Draws the app icon at every size the catalogues ask for.
//
// The mark is a 3x3 grid, not a 9x9 one. At 40 points a full sudoku grid is
// grey mush; three by three still reads as "sudoku" and stays legible down to
// the smallest macOS size. Four digits sit in it, in the app's own accent
// colour, placed asymmetrically so the icon has a direction.

let accent = (r: 0.086, g: 0.325, b: 0.541)
let digits: [(column: Int, row: Int, value: String)] = [
    (0, 0, "5"), (2, 0, "3"), (1, 1, "7"), (0, 2, "9"), (2, 2, "1"),
]

func makeContext(_ size: Int) -> CGContext {
    CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

/// `inset` leaves the rounded margin macOS icons are expected to have; iOS is
/// drawn full-bleed because the system applies its own mask.
func drawIcon(in context: CGContext, size: Double, inset: Double, corner: Double) {
    let box = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)

    context.saveGState()
    if corner > 0 {
        context.addPath(CGPath(roundedRect: box, cornerWidth: corner, cornerHeight: corner,
                               transform: nil))
        context.clip()
    }

    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.fill(box)

    // A hairline of the accent colour around the plate keeps the icon from
    // dissolving into a white background.
    context.setStrokeColor(red: accent.r, green: accent.g, blue: accent.b, alpha: 0.18)
    context.setLineWidth(size * 0.012)
    context.stroke(box.insetBy(dx: size * 0.006, dy: size * 0.006))

    let grid = box.insetBy(dx: box.width * 0.17, dy: box.height * 0.17)
    let cell = grid.width / 3

    context.setStrokeColor(red: accent.r, green: accent.g, blue: accent.b, alpha: 1)
    context.setLineWidth(max(1, size * 0.022))
    context.setLineCap(.round)
    for line in 0...3 {
        let offset = cell * Double(line)
        context.move(to: CGPoint(x: grid.minX + offset, y: grid.minY))
        context.addLine(to: CGPoint(x: grid.minX + offset, y: grid.maxY))
        context.move(to: CGPoint(x: grid.minX, y: grid.minY + offset))
        context.addLine(to: CGPoint(x: grid.maxX, y: grid.minY + offset))
    }
    context.strokePath()

    let fontSize = cell * 0.62
    let font = CTFontCreateWithName("SFRounded-Semibold" as CFString, fontSize, nil)
    // The colour has to be an attribute: CoreText does not pick up the context's
    // fill colour, it falls back to black.
    let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
    let colourKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
    let ink = CGColor(red: accent.r, green: accent.g, blue: accent.b, alpha: 1)
    for digit in digits {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: digit.value,
                               attributes: [fontKey: font, colourKey: ink]))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let centre = CGPoint(
            x: grid.minX + cell * (Double(digit.column) + 0.5),
            y: grid.minY + cell * (Double(2 - digit.row) + 0.5))
        context.textPosition = CGPoint(
            x: centre.x - bounds.width / 2 - bounds.minX,
            y: centre.y - bounds.height / 2 - bounds.minY)
        CTLineDraw(line, context)
    }
    context.restoreGState()
}

func write(_ context: CGContext, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("could not write \(path)") }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let root = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
let catalog = "\(root)/App/Sudoku/Assets.xcassets"

// iOS: full bleed, the system masks it.
do {
    let context = makeContext(1024)
    drawIcon(in: context, size: 1024, inset: 0, corner: 0)
    write(context, to: "\(catalog)/AppIcon.appiconset/icon-1024.png")
}

// macOS: its own rounded plate with the standard margin.
for (points, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
                        (256, 1), (256, 2), (512, 1), (512, 2)] {
    let pixels = points * scale
    let context = makeContext(pixels)
    let size = Double(pixels)
    drawIcon(in: context, size: size, inset: size * 0.09, corner: size * 0.20)
    write(context, to: "\(catalog)/AppIcon.appiconset/mac-\(points)x\(points)@\(scale)x.png")
}

// tvOS wants the icon in three layers so it can part them as focus moves over
// it: the plate behind, the grid in the middle, the digits in front. Landscape,
// with the art centred.
enum Layer { case back, middle, front }

func drawTVLayer(_ layer: Layer, in context: CGContext, width: Double, height: Double) {
    let side = min(width, height) * 0.82
    let box = CGRect(x: (width - side) / 2, y: (height - side) / 2, width: side, height: side)

    switch layer {
    case .back:
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    case .middle:
        let grid = box.insetBy(dx: side * 0.17, dy: side * 0.17)
        let cell = grid.width / 3
        context.setStrokeColor(red: accent.r, green: accent.g, blue: accent.b, alpha: 1)
        context.setLineWidth(max(1, side * 0.022))
        context.setLineCap(.round)
        for line in 0...3 {
            let offset = cell * Double(line)
            context.move(to: CGPoint(x: grid.minX + offset, y: grid.minY))
            context.addLine(to: CGPoint(x: grid.minX + offset, y: grid.maxY))
            context.move(to: CGPoint(x: grid.minX, y: grid.minY + offset))
            context.addLine(to: CGPoint(x: grid.maxX, y: grid.minY + offset))
        }
        context.strokePath()
    case .front:
        let grid = box.insetBy(dx: side * 0.17, dy: side * 0.17)
        let cell = grid.width / 3
        let font = CTFontCreateWithName("SFRounded-Semibold" as CFString, cell * 0.62, nil)
        let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
        let colourKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
        let ink = CGColor(red: accent.r, green: accent.g, blue: accent.b, alpha: 1)
        for digit in digits {
            let line = CTLineCreateWithAttributedString(
                NSAttributedString(string: digit.value,
                                   attributes: [fontKey: font, colourKey: ink]))
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            let centre = CGPoint(
                x: grid.minX + cell * (Double(digit.column) + 0.5),
                y: grid.minY + cell * (Double(2 - digit.row) + 0.5))
            context.textPosition = CGPoint(
                x: centre.x - bounds.width / 2 - bounds.minX,
                y: centre.y - bounds.height / 2 - bounds.minY)
            CTLineDraw(line, context)
        }
    }
}

func makeRectContext(width: Int, height: Int) -> CGContext {
    CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

let brand = "\(catalog)/App Icon & Top Shelf Image.brandassets"
let stacks = [("App Icon.imagestack", 400, 240), ("App Icon - App Store.imagestack", 1280, 768)]
let layers: [(String, Layer)] = [("Back", .back), ("Middle", .middle), ("Front", .front)]

for (stack, width, height) in stacks {
    for (name, layer) in layers {
        var entries: [String] = []
        for scale in [1, 2] {
            let context = makeRectContext(width: width * scale, height: height * scale)
            drawTVLayer(layer, in: context,
                        width: Double(width * scale), height: Double(height * scale))
            let file = "\(name.lowercased())@\(scale)x.png"
            write(context, to: "\(brand)/\(stack)/\(name).imagestacklayer/Content.imageset/\(file)")
            entries.append("{ \"filename\" : \"\(file)\", \"idiom\" : \"tv\", \"scale\" : \"\(scale)x\" }")
        }
        let json = "{ \"images\" : [ \(entries.joined(separator: ", ")) ], \"info\" : { \"author\" : \"xcode\", \"version\" : 1 } }\n"
        try? json.write(
            toFile: "\(brand)/\(stack)/\(name).imagestacklayer/Content.imageset/Contents.json",
            atomically: true, encoding: .utf8)
    }
}

// Top shelf: the same mark on a wide plate, well inside the safe area.
for (folder, width, height) in [("Top Shelf Image.imageset", 1920, 720),
                                ("Top Shelf Image Wide.imageset", 2320, 720)] {
    var entries: [String] = []
    for scale in [1, 2] {
        let context = makeRectContext(width: width * scale, height: height * scale)
        let w = Double(width * scale), h = Double(height * scale)
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        drawTVLayer(.middle, in: context, width: w, height: h)
        drawTVLayer(.front, in: context, width: w, height: h)
        let file = "top-shelf@\(scale)x.png"
        write(context, to: "\(brand)/\(folder)/\(file)")
        entries.append("{ \"filename\" : \"\(file)\", \"idiom\" : \"tv\", \"scale\" : \"\(scale)x\" }")
    }
    let json = "{ \"images\" : [ \(entries.joined(separator: ", ")) ], \"info\" : { \"author\" : \"xcode\", \"version\" : 1 } }\n"
    try? json.write(toFile: "\(brand)/\(folder)/Contents.json", atomically: true, encoding: .utf8)
}

print("icons rendered")
