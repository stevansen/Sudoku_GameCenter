import SwiftUI

/// Colours and metrics in one place, so the board looks the same everywhere.
public enum Theme {
    public static let boardLine = Color.primary.opacity(0.28)
    public static let boardLineStrong = Color.primary.opacity(0.65)

    public static let cellBackground = Color.clear
    public static let cellSelected = Color.accentColor.opacity(0.28)
    public static let cellPeer = Color.primary.opacity(0.06)
    public static let cellSameDigit = Color.accentColor.opacity(0.12)
    public static let cellHinted = Color.yellow.opacity(0.35)
    public static let cellWrong = Color.red.opacity(0.18)

    public static let givenDigit = Color.primary
    public static let enteredDigit = Color.accentColor
    public static let wrongDigit = Color.red
    public static let noteDigit = Color.secondary

    public static let thinLine: CGFloat = 1
    public static let thickLine: CGFloat = 2.5
    public static let boardCornerRadius: CGFloat = 6
}

extension Int {
    /// `12:34` — the timer format.
    var asClock: String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}
