import SwiftUI
import SudokuKit

/// The nine digits, plus the controls that change what pressing one does.
struct NumberPadView: View {
    @Bindable var session: GameSession
    var onPlay: () -> Void

    /// Nine across is fine under a thumb. On a television the same row would be
    /// nine tiny targets to steer a focus ring through, so it wraps instead.
    private var columns: [GridItem] {
        #if os(tvOS)
        Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)
        #else
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 9)
        #endif
    }

    private var minimumButtonHeight: CGFloat {
        #if os(tvOS)
        72
        #else
        48
        #endif
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...9, id: \.self) { digit in
                Button {
                    session.enter(digit)
                    onPlay()
                } label: {
                    Text(String(digit))
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, minHeight: minimumButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(session.inputMode == .note
                                      ? Color.secondary.opacity(0.15)
                                      : Color.accentColor.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .disabled(session.completedDigits.contains(digit))
                .opacity(session.completedDigits.contains(digit) ? 0.25 : 1)
                .accessibilityLabel(session.inputMode == .note
                    ? String(localized: "Notiz \(digit)")
                    : String(localized: "Ziffer \(digit)"))
            }
        }
    }
}
