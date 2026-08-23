#if os(macOS)
import SwiftUI
import SudokuKit

/// The Mac menu bar.
///
/// On the Mac a game like this is played with the keyboard, so everything the
/// on-screen controls do needs a menu item and a shortcut behind it.
public struct SudokuCommands: Commands {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Menu(String(localized: "Neues Spiel")) {
                ForEach(Array(Difficulty.allCases.enumerated()), id: \.element) { index, difficulty in
                    Button(difficulty.localizedName) {
                        Task { await model.startGame(difficulty: difficulty) }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            Button(String(localized: "Tagesrätsel")) {
                Task { await model.startDailyPuzzle() }
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button(String(localized: "Zur Übersicht")) { model.isPlaying = false }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(!model.isPlaying)
        }

        // The system undo items would talk to an UndoManager the game does not use.
        CommandGroup(replacing: .undoRedo) {
            Button(String(localized: "Rückgängig")) {
                model.session?.undo()
                _ = model.didPlay()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(model.session?.canUndo != true)

            Button(String(localized: "Wiederholen")) {
                model.session?.redo()
                _ = model.didPlay()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(model.session?.canRedo != true)
        }

        CommandMenu(String(localized: "Spiel")) {
            Button(String(localized: "Hinweis")) { model.session?.requestHint() }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(model.session == nil)

            Button(String(localized: "Notizen umschalten")) {
                guard let session = model.session else { return }
                session.inputMode = session.inputMode == .note ? .digit : .note
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(model.session == nil)

            Button(String(localized: "Kandidaten ausfüllen")) {
                model.session?.fillAutoCandidates()
                _ = model.didPlay()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(model.session == nil)

            Divider()

            Button(model.session?.isPaused == true
                   ? String(localized: "Fortsetzen")
                   : String(localized: "Pausieren")) {
                guard let session = model.session else { return }
                session.isPaused ? session.resume() : session.pause()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(model.session == nil)
        }
    }
}
#endif
