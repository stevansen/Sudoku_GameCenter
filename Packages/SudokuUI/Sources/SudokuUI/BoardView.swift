import SwiftUI
import SudokuKit

/// The 9×9 grid, with the block lines drawn over it.
public struct BoardView: View {
    @Bindable var session: GameSession

    public init(session: GameSession) {
        self.session = session
    }

    public var body: some View {
        let wrong = session.wrongCells()
        let conflicts = session.conflicts
        let hinted = Set(session.hint?.highlights ?? [])
        let hintTargets = Set((session.hint?.placements.map(\.cell) ?? [])
            + (session.hint?.eliminations.map(\.cell) ?? []))

        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cell = side / 9

            ZStack(alignment: .topLeading) {
                ForEach(0..<81, id: \.self) { index in
                    CellView(
                        value: session.isPaused && !session.isGiven(index) ? 0 : session.entries[index],
                        notes: session.isPaused ? 0 : session.notes[index],
                        isGiven: session.isGiven(index),
                        isSelected: session.selection == index,
                        isPeer: isPeer(of: session.selection, index),
                        isSameDigit: isSameDigit(index),
                        isWrong: wrong.contains(index),
                        isConflicting: conflicts.contains(index),
                        isHinted: hintTargets.contains(index)
                            || (hinted.contains(index) && hintTargets.isEmpty))
                    .frame(width: cell, height: cell)
                    .offset(
                        x: cell * CGFloat(Units.columnOf[index]),
                        y: cell * CGFloat(Units.rowOf[index]))
                    .onTapGesture { session.selection = index }
                }
                gridLines(cell: cell, side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .top) {
                if session.isPaused {
                    ZStack {
                        Rectangle().fill(.regularMaterial)
                        Label(String(localized: "Pausiert"), systemImage: "pause.fill")
                            .font(.title2)
                    }
                    .frame(width: side, height: side)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(String(localized: "Sudoku-Brett"))
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

    @ViewBuilder
    private func gridLines(cell: CGFloat, side: CGFloat) -> some View {
        ForEach(0...9, id: \.self) { index in
            let thick = index % 3 == 0
            let width = thick ? Theme.thickLine : Theme.thinLine
            let color = thick ? Theme.boardLineStrong : Theme.boardLine
            Rectangle()
                .fill(color)
                .frame(width: side, height: width)
                .offset(y: cell * CGFloat(index) - width / 2)
            Rectangle()
                .fill(color)
                .frame(width: width, height: side)
                .offset(x: cell * CGFloat(index) - width / 2)
        }
        .allowsHitTesting(false)
    }
}
