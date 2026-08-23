import SwiftUI
import SudokuKit

/// Undo, erase, notes, hint — the row under the board.
struct ControlBarView: View {
    @Bindable var session: GameSession
    var onPlay: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            control("arrow.uturn.backward", String(localized: "Rückgängig")) {
                session.undo()
                onPlay()
            }
            .disabled(!session.canUndo)

            control("eraser", String(localized: "Löschen")) {
                session.clear()
                onPlay()
            }

            control(session.inputMode == .note ? "pencil.circle.fill" : "pencil.circle",
                    String(localized: "Notizen")) {
                session.inputMode = session.inputMode == .note ? .digit : .note
            }
            .tint(session.inputMode == .note ? .accentColor : .primary)

            control("lightbulb", String(localized: "Hinweis")) {
                session.requestHint()
            }
        }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title2)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
