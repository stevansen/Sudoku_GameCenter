import SwiftUI
import SudokuKit

/// The nine digits, plus the controls that change what pressing one does.
struct NumberPadView: View {
    @Bindable var session: GameSession
    var onPlay: () -> Void

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 9)
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
                        .frame(maxWidth: .infinity, minHeight: 48)
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
