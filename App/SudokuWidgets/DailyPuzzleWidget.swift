import SudokuKit
import SwiftUI
import WidgetKit

/// Today's puzzle on the home screen.
///
/// The widget derives the puzzle itself rather than reading one the app stored.
/// It can, because the daily puzzle is a pure function of the date — the same
/// property that makes everyone's daily puzzle identical also means the widget
/// needs no shared container, no app group, and no entitlement to show the real
/// thing. Generating it measures around 50 ms, well inside a widget's budget.
struct DailyPuzzleEntry: TimelineEntry {
    let date: Date
    let puzzle: Puzzle
}

struct DailyPuzzleProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyPuzzleEntry {
        DailyPuzzleEntry(date: .now, puzzle: PuzzleGenerator.daily(for: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPuzzleEntry) -> Void) {
        completion(DailyPuzzleEntry(date: .now, puzzle: PuzzleGenerator.daily(for: .now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPuzzleEntry>) -> Void) {
        let now = Date.now
        let entry = DailyPuzzleEntry(date: now, puzzle: PuzzleGenerator.daily(for: now))

        // The puzzle changes at midnight UTC, which is when the seed changes.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let midnight = calendar.nextDate(
            after: now, matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)

        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

/// The givens only — a widget shows what today looks like, it is not played in.
struct MiniBoard: View {
    let puzzle: Puzzle

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                ForEach(0..<81, id: \.self) { index in
                    let digit = puzzle.givens.cells[index]
                    if digit != 0 {
                        Text(String(digit))
                            .font(.system(size: cell * 0.78, weight: .medium, design: .rounded))
                            .frame(width: cell, height: cell)
                            .position(
                                x: cell * (CGFloat(index % 9) + 0.5),
                                y: cell * (CGFloat(index / 9) + 0.5))
                    }
                }

                Path { path in
                    for line in 0...9 {
                        let offset = cell * CGFloat(line)
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(x: offset, y: side))
                        path.move(to: CGPoint(x: 0, y: offset))
                        path.addLine(to: CGPoint(x: side, y: offset))
                    }
                }
                .stroke(Color.primary.opacity(0.22), lineWidth: 0.5)

                Path { path in
                    for line in stride(from: 0, through: 9, by: 3) {
                        let offset = cell * CGFloat(line)
                        path.move(to: CGPoint(x: offset, y: 0))
                        path.addLine(to: CGPoint(x: offset, y: side))
                        path.move(to: CGPoint(x: 0, y: offset))
                        path.addLine(to: CGPoint(x: side, y: offset))
                    }
                }
                .stroke(Color.primary.opacity(0.55), lineWidth: 1)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct DailyPuzzleWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyPuzzleEntry

    var body: some View {
        switch family {
        case .systemSmall:
            MiniBoard(puzzle: entry.puzzle)
        default:
            HStack(spacing: 14) {
                MiniBoard(puzzle: entry.puzzle)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date, format: .dateTime.weekday(.wide))
                        .font(.headline)
                    Text(entry.date, format: .dateTime.day().month(.wide))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.puzzle.givens.cells.count { $0 != 0 })/81")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct DailyPuzzleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyPuzzle", provider: DailyPuzzleProvider()) { entry in
            DailyPuzzleWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "sudoku://daily"))
        }
        .configurationDisplayName("Tagesrätsel")
        .description("Das Rätsel des Tages — für alle das gleiche.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
