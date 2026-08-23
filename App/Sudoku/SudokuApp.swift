import SwiftUI
import SudokuUI

@main
struct SudokuApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 820)
        #endif
    }
}
