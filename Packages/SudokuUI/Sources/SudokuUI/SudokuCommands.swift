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
            Menu(String(localized: "Neues Spiel", bundle: .module)) {
                ForEach(Array(Difficulty.allCases.enumerated()), id: \.element) { index, difficulty in
                    Button(difficulty.localizedName) {
                        Task { await model.startGame(difficulty: difficulty) }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
            Button(String(localized: "Tagesrätsel", bundle: .module)) {
                Task { await model.startDailyPuzzle() }
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button(String(localized: "Zur Übersicht", bundle: .module)) { model.isPlaying = false }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(!model.isPlaying)
        }

        // The system undo items would talk to an UndoManager the game does not use.
        CommandGroup(replacing: .undoRedo) {
            Button(String(localized: "Rückgängig", bundle: .module)) {
                model.session?.undo()
                _ = model.didPlay()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(model.session?.canUndo != true)

            Button(String(localized: "Wiederholen", bundle: .module)) {
                model.session?.redo()
                _ = model.didPlay()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(model.session?.canRedo != true)
        }

        CommandMenu(String(localized: "Spiel", bundle: .module)) {
            Button(String(localized: "Hinweis", bundle: .module)) { model.session?.requestHint() }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(model.session == nil)

            Button(String(localized: "Notizen umschalten", bundle: .module)) {
                guard let session = model.session else { return }
                session.inputMode = session.inputMode == .note ? .digit : .note
            }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(model.session == nil)

            Button(String(localized: "Kandidaten ausfüllen", bundle: .module)) {
                model.session?.fillAutoCandidates()
                _ = model.didPlay()
            }
            .keyboardShortcut("k", modifiers: .command)
            .disabled(model.session == nil)

            Divider()

            Button(model.session?.isPaused == true
                   ? String(localized: "Fortsetzen", bundle: .module)
                   : String(localized: "Pausieren", bundle: .module)) {
                guard let session = model.session else { return }
                session.isPaused ? session.resume() : session.pause()
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(model.session == nil)
        }
    }
}
#endif
