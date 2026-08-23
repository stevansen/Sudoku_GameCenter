#if canImport(GameKit) && canImport(SwiftUI)
import GameKit
import SwiftUI

/// Game Center's own leaderboard and achievement screens, wrapped for SwiftUI.
///
/// Apple's UI is used rather than a home-made one on purpose: players already
/// know it, and reimplementing it would mean re-fetching everything by hand.
public struct GameCenterDashboard: View {
    public enum Page: Sendable {
        case dashboard, leaderboards, achievements

        var state: GKGameCenterViewControllerState {
            switch self {
            case .dashboard: .dashboard
            case .leaderboards: .leaderboards
            case .achievements: .achievements
            }
        }
    }

    let page: Page
    @Environment(\.dismiss) private var dismiss

    public init(page: Page = .dashboard) {
        self.page = page
    }

    public var body: some View {
        Representable(state: page.state) { dismiss() }
            .ignoresSafeArea()
    }

    #if os(macOS)
    private struct Representable: NSViewControllerRepresentable {
        let state: GKGameCenterViewControllerState
        let onFinish: () -> Void

        func makeNSViewController(context: Context) -> GKGameCenterViewController {
            let controller = GKGameCenterViewController(state: state)
            controller.gameCenterDelegate = context.coordinator
            return controller
        }

        func updateNSViewController(_ controller: GKGameCenterViewController, context: Context) {}
        func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }
    }
    #else
    private struct Representable: UIViewControllerRepresentable {
        let state: GKGameCenterViewControllerState
        let onFinish: () -> Void

        func makeUIViewController(context: Context) -> GKGameCenterViewController {
            let controller = GKGameCenterViewController(state: state)
            controller.gameCenterDelegate = context.coordinator
            return controller
        }

        func updateUIViewController(_ controller: GKGameCenterViewController, context: Context) {}
        func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }
    }
    #endif

    final class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func gameCenterViewControllerDidFinish(_ controller: GKGameCenterViewController) {
            onFinish()
        }
    }
}
#endif
