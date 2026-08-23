import SwiftUI
import SudokuKit

/// What the puzzle was worth, and why.
///
/// The breakdown is shown in full on purpose: a score you cannot check is a
/// score you cannot trust, and the leaderboard depends on that trust.
public struct ResultSheetView: View {
    let breakdown: ScoreBreakdown
    let session: GameSession
    var onDone: () -> Void

    public init(breakdown: ScoreBreakdown, session: GameSession, onDone: @escaping () -> Void) {
        self.breakdown = breakdown
        self.session = session
        self.onDone = onDone
    }

    public var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(String(localized: "Gelöst"))
                    .font(.largeTitle.weight(.semibold))
                Text("\(session.puzzle.difficulty.localizedName) · \(session.elapsedSeconds.asClock)")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                row(String(localized: "Grundwert"), String(breakdown.base))
                row(String(localized: "Zeitfaktor"), factor(breakdown.timeFactor))
                if breakdown.mistakeFactor < 1 {
                    row(String(localized: "Fehler (\(session.mistakes))"), factor(breakdown.mistakeFactor))
                }
                if breakdown.hintFactor < 1 {
                    row(String(localized: "Hinweise (\(session.hintsUsed))"), factor(breakdown.hintFactor))
                }
                if breakdown.streakBonus > 0 {
                    row(String(localized: "Serie"), "+\(Int(breakdown.streakBonus * 100)) %")
                }
                Divider().padding(.vertical, 6)
                row(String(localized: "Punkte"), String(breakdown.total), emphasised: true)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))

            if let hardest = session.puzzle.hardestTechnique {
                Text(String(localized: "Schwerste nötige Technik: \(HintText.name(for: hardest))"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button(String(localized: "Fertig"), action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: 420)
    }

    private func row(_ label: String, _ value: String, emphasised: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(emphasised ? .headline : .subheadline)
        .padding(.vertical, 3)
    }

    private func factor(_ value: Double) -> String {
        String(format: "×%.2f", value)
    }
}
