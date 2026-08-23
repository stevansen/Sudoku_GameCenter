import CoreGraphics
import Foundation

let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}
for window in windows {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    guard owner == (CommandLine.arguments.dropFirst().first ?? "Sudoku") else { continue }
    let id = window[kCGWindowNumber as String] as? Int ?? 0
    let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let w = bounds["Width"] as? Double ?? 0
    let h = bounds["Height"] as? Double ?? 0
    guard w > 200, h > 200 else { continue }
    print("\(id) \(Int(w))x\(Int(h))")
}
