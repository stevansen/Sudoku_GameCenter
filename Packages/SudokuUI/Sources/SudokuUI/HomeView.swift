import SwiftUI
import SudokuKit

/// Difficulty picker and the way back into a running game.
public struct HomeView: View {
    var model: AppModel
    var onStart: (Difficulty) -> Void
    var onContinue: () -> Void

    public init(model: AppModel, onStart: @escaping (Difficulty) -> Void, onContinue: @escaping () -> Void) {
        self.model = model
        self.onStart = onStart
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsHeader

                if model.canContinue, let session = model.session {
                    Button(action: onContinue) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Weiterspielen"))
                                .font(.headline)
                            Text("\(session.puzzle.difficulty.localizedName) · \(session.elapsedSeconds.asClock) · \(session.filledCount)/81")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 10) {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Button { onStart(difficulty) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(difficulty.localizedName).font(.headline)
                                    Text(difficulty.localizedSubtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(model.stats.solvedCountByDifficulty[difficulty.rawValue] ?? 0))
                                    .font(.system(.subheadline, design: .rounded).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isPreparing)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Sudoku")
    }

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statistic(String(localized: "Punkte"), String(model.stats.totalPoints))
            statistic(String(localized: "Gelöst"), String(model.stats.solvedPuzzleIDs.count))
            statistic(String(localized: "Serie"), String(model.stats.streakDays))
        }
    }

    private func statistic(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
