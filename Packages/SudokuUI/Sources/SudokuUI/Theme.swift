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
    /// A wrong digit sits on a red-tinted cell, so plain `.red` on that tint
    /// measures under 4.5:1 and Xcode's audit fails it outright — in the one
    /// state where being able to read the number matters most. These are the
    /// same hue, moved far enough from the background in each appearance.
    public static func wrongDigit(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 1.00, green: 0.48, blue: 0.42)
            : Color(red: 0.62, green: 0.05, blue: 0.05)
    }
    public static let noteDigit = Color.primary.opacity(0.62)

    /// Quieter than the body text, but not so quiet it fails a contrast check.
    ///
    /// SwiftUI's `.secondary` renders as roughly #8E8E93 on white — about 3.5:1,
    /// under the 4.5:1 that normal-size text is meant to meet, and Xcode's
    /// accessibility audit flags every label using it. This sits near 7:1 and
    /// still reads as secondary.
    public static let secondaryText = Color.primary.opacity(0.75)

    public static let thinLine: CGFloat = 1
    public static let thickLine: CGFloat = 2.5
    public static let boardCornerRadius: CGFloat = 6

    /// How wide the controls beside the board may get. A television needs more:
    /// its buttons carry a focus halo and are read from across a room.
    public static var sidebarMaxWidth: CGFloat {
        #if os(tvOS)
        620
        #else
        420
        #endif
    }

    /// How wide a column of content may get.
    ///
    /// A television is far away and its screen is wide: the phone's 520 points
    /// leave the middle third of a 16:9 display carrying everything while two
    /// thirds sit empty.
    public static var contentMaxWidth: CGFloat {
        #if os(tvOS)
        1000
        #else
        520
        #endif
    }
}

extension Int {
    /// `12:34` — the timer format.
    var asClock: String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}
