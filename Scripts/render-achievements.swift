#!/usr/bin/env swift
import AppKit
import Foundation

// Die 30 Erfolgsbilder für Game Center: 512 × 512, ohne Alphakanal.
//
// Ein System statt dreißig Einfällen: derselbe blaue Grund wie das App-Symbol,
// ein weißes SF-Symbol in der Mitte, und wo ein Erfolg eine Stufe in einer Reihe
// ist, die Zahl darunter. So sind sie in der Liste auseinanderzuhalten, ohne
// dass jedes einzeln gestaltet werden müsste.

struct Badge {
    let name: String
    let symbol: String
    var caption: String? = nil
}

let badges: [Badge] = [
    .init(name: "first_solve", symbol: "checkmark.circle.fill"),
    .init(name: "solve_10", symbol: "square.grid.3x3.fill", caption: "10"),
    .init(name: "solve_50", symbol: "square.grid.3x3.fill", caption: "50"),
    .init(name: "solve_250", symbol: "square.grid.3x3.fill", caption: "250"),
    .init(name: "solve_1000", symbol: "square.grid.3x3.fill", caption: "1000"),
    .init(name: "easy_master", symbol: "leaf.fill"),
    .init(name: "medium_master", symbol: "moon.stars.fill"),
    .init(name: "hard_master", symbol: "flame.fill"),
    .init(name: "expert_master", symbol: "bolt.fill"),
    .init(name: "evil_master", symbol: "crown.fill"),
    .init(name: "flawless", symbol: "checkmark.seal.fill"),
    .init(name: "flawless_expert", symbol: "seal.fill"),
    .init(name: "no_hints_50", symbol: "lightbulb.slash.fill", caption: "50"),
    .init(name: "speed_easy_180", symbol: "hare.fill"),
    .init(name: "speed_hard_600", symbol: "bolt.horizontal.fill"),
    .init(name: "speed_evil_1800", symbol: "figure.run"),
    .init(name: "streak_7", symbol: "flame", caption: "7"),
    .init(name: "streak_30", symbol: "flame.fill", caption: "30"),
    .init(name: "streak_365", symbol: "calendar.badge.clock", caption: "365"),
    .init(name: "first_daily", symbol: "calendar"),
    .init(name: "daily_10", symbol: "calendar.badge.checkmark", caption: "10"),
    .init(name: "daily_100", symbol: "calendar.badge.plus", caption: "100"),
    .init(name: "night_owl", symbol: "moon.zzz.fill"),
    .init(name: "early_bird", symbol: "sunrise.fill"),
    .init(name: "points_10k", symbol: "star.fill", caption: "10k"),
    .init(name: "points_100k", symbol: "star.circle.fill", caption: "100k"),
    .init(name: "all_platforms", symbol: "macbook.and.iphone"),
    .init(name: "comeback", symbol: "arrow.triangle.2.circlepath"),
    .init(name: "technique_xwing", symbol: "xmark.diamond.fill"),
    .init(name: "perfect_week", symbol: "rosette"),
]

let size = 512
let accent = NSColor(srgbRed: 0.086, green: 0.325, blue: 0.541, alpha: 1)
let deep = NSColor(srgbRed: 0.043, green: 0.196, blue: 0.337, alpha: 1)

let outputDirectory = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : NSHomeDirectory() + "/Developer/Sudoku-Achievements"
try? FileManager.default.createDirectory(atPath: outputDirectory,
                                         withIntermediateDirectories: true)

var written = 0
var missing: [String] = []

for badge in badges {
    guard let symbol = NSImage(systemSymbolName: badge.symbol, accessibilityDescription: nil) else {
        missing.append("\(badge.name) (\(badge.symbol))")
        continue
    }

    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    // Grund: derselbe Blauverlauf für alle, damit die Reihe zusammengehört.
    let gradient = NSGradient(starting: accent, ending: deep)!
    gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

    let hasCaption = badge.caption != nil
    let glyphSide = CGFloat(size) * (hasCaption ? 0.42 : 0.52)
    let glyphY = hasCaption ? CGFloat(size) * 0.40 : CGFloat(size) * 0.29

    let configuration = NSImage.SymbolConfiguration(pointSize: glyphSide, weight: .semibold)
    let glyph = symbol.withSymbolConfiguration(configuration) ?? symbol
    let tinted = NSImage(size: glyph.size)
    tinted.lockFocus()
    NSColor.white.set()
    NSRect(origin: .zero, size: glyph.size).fill(using: .sourceOver)
    glyph.draw(at: .zero, from: NSRect(origin: .zero, size: glyph.size),
               operation: .destinationIn, fraction: 1)
    tinted.unlockFocus()

    let drawn = NSRect(x: (CGFloat(size) - tinted.size.width) / 2, y: glyphY,
                       width: tinted.size.width, height: tinted.size.height)
    tinted.draw(in: drawn)

    if let caption = badge.caption {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(size) * 0.20, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: style,
        ]
        let text = caption as NSString
        let height = text.size(withAttributes: attributes).height
        text.draw(in: NSRect(x: 0, y: CGFloat(size) * 0.16,
                             width: CGFloat(size), height: height),
                  withAttributes: attributes)
    }

    image.unlockFocus()

    // Ohne Alphakanal neu zeichnen — App Store Connect weist Bilder mit Alpha ab.
    guard let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { continue }
    context.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
    guard let flattened = context.makeImage() else { continue }

    let bitmap = NSBitmapImageRep(cgImage: flattened)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { continue }
    try? data.write(to: URL(fileURLWithPath: "\(outputDirectory)/\(badge.name).png"))
    written += 1
}

print("\(written) von \(badges.count) Bildern geschrieben nach \(outputDirectory)")
if !missing.isEmpty { print("Symbol nicht gefunden: " + missing.joined(separator: ", ")) }
