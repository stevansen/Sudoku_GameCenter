import SwiftUI
import SudokuKit

/// The playing screen: board, controls, keypad.
public struct GameView: View {
    @Bindable var session: GameSession
    var model: AppModel

    public init(session: GameSession, model: AppModel) {
        self.session = session
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 16) {
            header
            BoardView(session: session)
                .padding(.horizontal, 4)
            if let hint = session.hint {
                hintCard(hint)
            }
            // Board sits under the header, controls stay at the bottom edge —
            // without this the whole stack floats in the middle of the screen.
            Spacer(minLength: 0)
            ControlBarView(session: session, onPlay: model.didPlay)
            NumberPadView(session: session, onPlay: model.didPlay)
        }
        .padding()
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
        // Without this the empty large-title area eats a fifth of the screen.
        .toolbarTitleDisplayMode(.inline)
        .task {
            // One clock for the whole screen, stopped when the view goes away.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                model.tick()
            }
        }
        #if os(macOS)
        .focusable()
        .onKeyPress { press in handleKey(press) }
        #endif
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.puzzle.difficulty.localizedName)
                    .font(.headline)
                Text(String(localized: "Fehler \(session.mistakes) · Hinweise \(session.hintsUsed)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                session.isPaused ? session.resume() : session.pause()
            } label: {
                Label(session.elapsedSeconds.asClock,
                      systemImage: session.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(.headline, design: .rounded).monospacedDigit())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.isPaused
                ? String(localized: "Fortsetzen")
                : String(localized: "Pausieren, \(session.elapsedSeconds.asClock)"))
        }
    }

    private func hintCard(_ hint: Deduction) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(HintText.headline(for: hint))
                .font(.subheadline.weight(.semibold))
            Text(HintText.explanation(for: hint))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(String(localized: "Verstanden")) { session.dismissHint() }
                    .buttonStyle(.bordered)
                if hint.placements.first != nil {
                    Button(String(localized: "Eintragen")) {
                        session.applyHint()
                        model.didPlay()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.15)))
    }

    #if os(macOS)
    /// Keyboard first on the Mac: arrows move, 1–9 place, shift+digit notes.
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let selection = session.selection ?? 0
        switch press.key {
        case .upArrow: session.selection = max(0, selection - 9); return .handled
        case .downArrow: session.selection = min(80, selection + 9); return .handled
        case .leftArrow: session.selection = max(0, selection - 1); return .handled
        case .rightArrow: session.selection = min(80, selection + 1); return .handled
        case .delete, .deleteForward: session.clear(); model.didPlay(); return .handled
        case .space: session.isPaused ? session.resume() : session.pause(); return .handled
        default: break
        }
        if let digit = press.characters.first?.wholeNumberValue, (1...9).contains(digit) {
            let mode = session.inputMode
            if press.modifiers.contains(.shift) { session.inputMode = .note }
            session.enter(digit)
            session.inputMode = mode
            model.didPlay()
            return .handled
        }
        return .ignored
    }
    #endif
}
