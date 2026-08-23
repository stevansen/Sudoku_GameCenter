import SwiftUI
import SudokuKit
import SudokuSync

/// The app's one entry point, shared by every platform.
public struct RootView: View {
    @State private var model: AppModel

    public init(model: AppModel = AppModel()) {
        _model = State(initialValue: model)
    }

    static func conflictMessage(_ conflict: AppModel.SyncConflict) -> String {
        let remote = conflict.remote
        let filled = remote.filledCells
        switch conflict.reason {
        case .differentPuzzle:
            return String(localized: "Auf \u{201E}\(remote.deviceName)\u{201C} läuft ein anderes Rätsel (\(filled) von 81 Feldern, \(remote.elapsedSeconds.asClock)). Welches möchtest du fortsetzen?")
        case .contradictingEntries:
            return String(localized: "Auf \u{201E}\(remote.deviceName)\u{201C} steht dasselbe Rätsel anders (\(filled) von 81 Feldern, \(remote.moveCount) Züge). Welchen Stand möchtest du behalten?")
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isPlaying, let session = model.session {
                    GameView(session: session, model: model)
                } else {
                    HomeView(
                        model: model,
                        onStart: { difficulty in
                            Task { await model.startGame(difficulty: difficulty) }
                        },
                        onContinue: { model.isPlaying = true },
                        onStartDaily: {
                            Task { await model.startDailyPuzzle() }
                        })
                }
            }
            .toolbar {
                if model.isPlaying {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Zurück")) { model.isPlaying = false }
                    }
                }
            }
        }
        .task { await model.load() }
        .alert(
            String(localized: "Anderer Spielstand gefunden"),
            isPresented: .constant(model.pendingConflict != nil),
            presenting: model.pendingConflict
        ) { conflict in
            Button(String(localized: "Diesen übernehmen")) {
                Task { await model.resolveConflict(keepRemote: true) }
            }
            Button(String(localized: "Lokalen behalten"), role: .cancel) {
                Task { await model.resolveConflict(keepRemote: false) }
            }
        } message: { conflict in
            Text(Self.conflictMessage(conflict))
        }
        .sheet(isPresented: .constant(model.lastResult != nil)) {
            if let breakdown = model.lastResult, let session = model.session {
                ResultSheetView(breakdown: breakdown, session: session) {
                    model.dismissResult()
                    model.isPlaying = false
                }
                .interactiveDismissDisabled()
            }
        }
    }
}
