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
                Text(String(localized: "Gelöst", bundle: .module))
                    .font(.largeTitle.weight(.semibold))
                Text("\(session.puzzle.difficulty.localizedName) · \(session.elapsedSeconds.asClock)")
                    .foregroundStyle(Theme.secondaryText)
            }

            VStack(spacing: 0) {
                row(String(localized: "Grundwert", bundle: .module), String(breakdown.base))
                row(String(localized: "Zeitfaktor", bundle: .module), factor(breakdown.timeFactor))
                if breakdown.mistakeFactor < 1 {
                    row(String(localized: "Fehler (\(session.mistakes))", bundle: .module), factor(breakdown.mistakeFactor))
                }
                if breakdown.hintFactor < 1 {
                    row(String(localized: "Hinweise (\(session.hintsUsed))", bundle: .module), factor(breakdown.hintFactor))
                }
                if breakdown.streakBonus > 0 {
                    row(String(localized: "Serie", bundle: .module), "+\(Int(breakdown.streakBonus * 100)) %")
                }
                Divider().padding(.vertical, 6)
                row(String(localized: "Punkte", bundle: .module), String(breakdown.total), emphasised: true)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))

            if let hardest = session.puzzle.hardestTechnique {
                Text(String(localized: "Schwerste nötige Technik: \(HintText.name(for: hardest))", bundle: .module))
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }

            Button(String(localized: "Fertig", bundle: .module), action: onDone)
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
