import SwiftUI
import SudokuKit

/// The 9×9 grid, with the block lines drawn over it.
///
/// Laid out as real rows and columns rather than one absolutely positioned
/// layer. That costs nothing on a touch screen and is the difference between
/// working and not working on Apple TV, where the focus engine moves between
/// views by their actual frames.
public struct BoardView: View {
    @Bindable var session: GameSession
    #if os(tvOS)
    @FocusState private var focusedCell: Int?
    #endif

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        let wrong = session.wrongCells()
        let conflicts = session.conflicts
        let highlights = Set(session.hint?.highlights ?? [])
        let hintTargets = Set((session.hint?.placements.map(\.cell) ?? [])
            + (session.hint?.eliminations.map(\.cell) ?? []))

        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { column in
                        let index = row * 9 + column
                        cell(
                            at: index,
                            isWrong: wrong.contains(index),
                            isConflicting: conflicts.contains(index),
                            isHinted: hintTargets.contains(index)
                                || (highlights.contains(index) && hintTargets.isEmpty))
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay { gridLines }
        .overlay { pausedOverlay }
        #if os(tvOS)
        .onChange(of: focusedCell) { _, new in
            if let new { session.selection = new }
        }
        #endif
        // `.contain`, not the default. Giving a container a label turns the whole
        // grid into one element and hides all 81 cells behind it — VoiceOver
        // would read "Sudoku board" and offer no way in.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Sudoku-Brett", bundle: .module))
    }

    @ViewBuilder
    private func cell(at index: Int, isWrong: Bool, isConflicting: Bool, isHinted: Bool) -> some View {
        let view = CellView(
            value: session.isPaused && !session.isGiven(index) ? 0 : session.entries[index],
            notes: session.isPaused ? 0 : session.notes[index],
            isGiven: session.isGiven(index),
            isSelected: session.selection == index,
            isPeer: isPeer(of: session.selection, index),
            isSameDigit: isSameDigit(index),
            isWrong: isWrong,
            isConflicting: isConflicting,
            isHinted: isHinted,
            row: Units.rowOf[index],
            column: Units.columnOf[index])

        let positioned = view

        // A real button on every platform, not a tap gesture. A gesture gives
        // VoiceOver nothing to activate: the audit reports "Action is missing",
        // and in practice a cell could be heard but never chosen. The remote on
        // tvOS needs it to be a focus target anyway.
        Button { session.selection = index } label: { positioned }
            .buttonStyle(.plain)
            #if os(tvOS)
            .focused($focusedCell, equals: index)
            #endif
    }

    @ViewBuilder
    private var pausedOverlay: some View {
        if session.isPaused {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Label(String(localized: "Pausiert", bundle: .module), systemImage: "pause.fill")
                    .font(.title2)
            }
        }
    }

    private func isPeer(of selection: Int?, _ index: Int) -> Bool {
        guard let selection, selection != index else { return false }
        return Units.sees(selection, index)
    }

    private func isSameDigit(_ index: Int) -> Bool {
        guard let selection = session.selection,
              selection != index,
              session.entries[selection] != 0
        else { return false }
        return session.entries[index] == session.entries[selection]
    }

    private var gridLines: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let step = side / 9
            ForEach(0...9, id: \.self) { index in
                let thick = index % 3 == 0
                let width = thick ? Theme.thickLine : Theme.thinLine
                let color = thick ? Theme.boardLineStrong : Theme.boardLine
                Rectangle()
                    .fill(color)
                    .frame(width: side, height: width)
                    .offset(y: step * CGFloat(index) - width / 2)
                Rectangle()
                    .fill(color)
                    .frame(width: width, height: side)
                    .offset(x: step * CGFloat(index) - width / 2)
            }
        }
        .allowsHitTesting(false)
    }
}
