import SwiftUI
import SudokuKit

/// Undo, erase, notes, hint — the row under the board.
struct ControlBarView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var session: GameSession
    var onPlay: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            control("arrow.uturn.backward", String(localized: "Rückgängig", bundle: .module)) {
                session.undo()
                onPlay()
            }
            .disabled(!session.canUndo)

            control("eraser", String(localized: "Löschen", bundle: .module)) {
                session.clear()
                onPlay()
            }

            control(session.inputMode == .note ? "pencil.circle.fill" : "pencil.circle",
                    String(localized: "Notizen", bundle: .module)) {
                session.inputMode = session.inputMode == .note ? .digit : .note
            }
            .tint(session.inputMode == .note ? .accentColor : .primary)
            // Whether notes mode is on was carried by the tint alone, which says
            // nothing to a screen reader — or to anyone who cannot tell the two
            // tints apart.
            .accessibilityAddTraits(session.inputMode == .note ? [.isSelected] : [])

            control("lightbulb", String(localized: "Hinweis", bundle: .module)) {
                session.requestHint()
            }
        }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(dynamicTypeSize.isAccessibilitySize ? .largeTitle : .title2)
                // At the accessibility sizes the captions wrapped to three lines
                // each — "Rückgängig" became "Rüc/kgä/ngig" — and pushed the
                // board down to a third of its size. The board is the thing the
                // app is for, so past a point the icons carry the row alone. The
                // name is still on the button for VoiceOver to read.
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(label)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
