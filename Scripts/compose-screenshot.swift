#!/usr/bin/env swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Two jobs, both about what App Store Connect will accept.
//
//   compose-screenshot.swift <in> <out> <width> <height>
//       Centres a window capture on an opaque canvas of the required size. A Mac
//       window is 5:4 and the store wants 16:10, so it cannot simply be scaled.
//
//   compose-screenshot.swift --flatten <file> ...
//       Re-encodes without an alpha channel. The simulator writes screenshots
//       with alpha even though every pixel is opaque, and they are rejected for
//       it.

func load(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)
    else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func opaqueContext(width: Int, height: Int, red: Double, green: Double, blue: Double) -> CGContext {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
}

func write(_ context: CGContext, to path: String) {
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("could not write \(path)") }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.first == "--flatten" {
    for path in arguments.dropFirst() {
        guard let image = load(path) else { continue }
        let context = opaqueContext(width: image.width, height: image.height,
                                    red: 1, green: 1, blue: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        write(context, to: path)
    }
    print("flattened \(arguments.count - 1)")
} else {
    guard arguments.count >= 4, let width = Int(arguments[2]), let height = Int(arguments[3]),
          let image = load(arguments[0])
    else { fatalError("usage: compose-screenshot <in> <out> <width> <height>") }

    let context = opaqueContext(width: width, height: height,
                                red: 0.94, green: 0.95, blue: 0.96)
    let scale = min(Double(width) * 0.82 / Double(image.width),
                    Double(height) * 0.86 / Double(image.height))
    let w = Double(image.width) * scale, h = Double(image.height) * scale
    context.draw(image, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2,
                                   width: w, height: h))
    write(context, to: arguments[1])
    print("\(width)x\(height)")
}
