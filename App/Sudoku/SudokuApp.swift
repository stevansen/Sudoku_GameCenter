import SwiftUI
import SudokuUI

@main
struct SudokuApp: App {
    /// Owned here rather than inside the root view so the Mac menu bar can reach it.
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 720)
        .commands { SudokuCommands(model: model) }
        #endif
    }
}
