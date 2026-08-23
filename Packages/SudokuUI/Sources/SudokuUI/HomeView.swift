import SwiftUI
import SudokuGameCenter
import SudokuKit

/// Difficulty picker and the way back into a running game.
public struct HomeView: View {
    var model: AppModel
    var onStart: (Difficulty) -> Void
    var onContinue: () -> Void
    var onStartDaily: () -> Void
    @State private var showsGameCenter = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        model: AppModel,
        onStart: @escaping (Difficulty) -> Void,
        onContinue: @escaping () -> Void,
        onStartDaily: @escaping () -> Void
    ) {
        self.model = model
        self.onStart = onStart
        self.onContinue = onContinue
        self.onStartDaily = onStartDaily
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statsHeader
                gameCenterButton
                dailyButton

                if model.canContinue, let session = model.session {
                    Button(action: onContinue) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Weiterspielen", bundle: .module))
                                .font(.headline)
                            Text("\(session.puzzle.difficulty.localizedName) · \(session.elapsedSeconds.asClock) · \(session.filledCount)/81")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
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
                                        .fixedSize(horizontal: false, vertical: true)
                                        .font(.caption)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Text(String(model.stats.solvedCountByDifficulty[difficulty.rawValue] ?? 0))
                                    .font(.system(.subheadline, design: .rounded).monospacedDigit())
                                    .foregroundStyle(Theme.secondaryText)
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
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Sudoku")
        #if canImport(GameKit)
        .sheet(isPresented: $showsGameCenter) {
            GameCenterDashboard(page: .leaderboards)
        }
        #endif
    }

    private var dailyButton: some View {
        Button(action: onStartDaily) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Tagesrätsel", bundle: .module)).font(.headline)
                    Text(model.hasSolvedTodaysPuzzle
                        ? String(localized: "Heute schon gelöst", bundle: .module)
                        : String(localized: "Für alle das gleiche · doppelte Punkte", bundle: .module))
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        // At the larger text sizes this line is cut off rather
                        // than wrapped, which the dynamic type audit catches.
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: model.hasSolvedTodaysPuzzle ? "checkmark.circle.fill" : "calendar")
                    .foregroundStyle(model.hasSolvedTodaysPuzzle ? Color.green : Color.accentColor)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .disabled(model.isPreparing)
    }

    @ViewBuilder
    private var gameCenterButton: some View {
        #if canImport(GameKit)
        Button { showsGameCenter = true } label: {
            Label(
                model.isSignedInToGameCenter
                    ? String(localized: "Bestenlisten & Erfolge", bundle: .module)
                    : String(localized: "Bei Game Center anmelden", bundle: .module),
                systemImage: "trophy")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        #endif
    }

    private var statsHeader: some View {
        // Three columns across a phone works until the text gets big, at which
        // point each column is too narrow for its own single word and "Punkte"
        // is hyphenated into "Punkt-/e". At the accessibility sizes the three
        // stack instead.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 0))

        return layout {
            statistic(String(localized: "Punkte", bundle: .module), String(model.stats.totalPoints))
            statistic(String(localized: "Gelöst", bundle: .module), String(model.stats.solvedPuzzleIDs.count))
            statistic(String(localized: "Serie", bundle: .module), String(model.stats.streakDays))
        }
    }

    private func statistic(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        // The number and its caption were two separate unnamed elements. On the
        // Mac, VoiceOver announced the first of them as "Textelement" — no
        // number, no name, nothing to go on. As one element it reads "0 Punkte".
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
        // Without a role the Mac audit reports "Unknown role": an element with a
        // name but nothing saying what kind of thing it is.
        .accessibilityAddTraits(.isStaticText)
    }
}
