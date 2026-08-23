import SwiftUI

/// Shown once, the first time the app is opened.
///
/// Sudoku itself needs no teaching — the rules are older than everyone reading
/// this. What does need saying is what *this* app does with them: that the daily
/// puzzle is the same one everyone else is solving, that mistakes are counted
/// rather than blocked, and that a hint explains its reasoning instead of just
/// filling a cell.
struct OnboardingView: View {
    var onDismiss: () -> Void

    private struct Point: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private var points: [Point] {
        [
            Point(
                symbol: "calendar",
                title: String(localized: "Tagesrätsel", bundle: .module),
                detail: String(localized: "Für alle das gleiche · doppelte Punkte", bundle: .module)),
            Point(
                symbol: "pencil.and.list.clipboard",
                title: String(localized: "Notizen", bundle: .module),
                detail: String(localized: "Kandidaten ausfüllen", bundle: .module)),
            Point(
                symbol: "lightbulb",
                title: String(localized: "Hinweis", bundle: .module),
                detail: String(localized: "Erklärt den Schluss, statt nur die Zahl zu setzen", bundle: .module)),
        ]
    }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.accentColor)
                Text(String(localized: "Sudoku", bundle: .module))
                    .font(.largeTitle.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 20) {
                ForEach(points) { point in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: point.symbol)
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 34)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(point.title).font(.headline)
                            Text(point.detail)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: 420)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Text(String(localized: "Verstanden", bundle: .module))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: 420)
        }
        .padding(28)
        .multilineTextAlignment(.leading)
    }
}
