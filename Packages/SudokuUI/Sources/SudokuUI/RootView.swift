import SwiftUI
import SudokuKit

/// The app's one entry point, shared by every platform.
public struct RootView: View {
    @State private var model = AppModel()
    @State private var isPlaying = false

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if isPlaying, let session = model.session {
                    GameView(session: session, model: model)
                } else {
                    HomeView(
                        model: model,
                        onStart: { difficulty in
                            Task {
                                await model.startGame(difficulty: difficulty)
                                isPlaying = true
                            }
                        },
                        onContinue: { isPlaying = true })
                }
            }
            .toolbar {
                if isPlaying {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "Zurück")) { isPlaying = false }
                    }
                }
            }
        }
        .task { await model.load() }
        .sheet(isPresented: .constant(model.lastResult != nil)) {
            if let breakdown = model.lastResult, let session = model.session {
                ResultSheetView(breakdown: breakdown, session: session) {
                    model.dismissResult()
                    isPlaying = false
                }
                .interactiveDismissDisabled()
            }
        }
    }
}
