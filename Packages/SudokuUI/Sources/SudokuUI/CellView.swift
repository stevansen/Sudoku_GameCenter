import SwiftUI
import SudokuKit

/// One square of the board.
struct CellView: View {
    let value: UInt8
    let notes: Candidates
    let isGiven: Bool
    let isSelected: Bool
    let isPeer: Bool
    let isSameDigit: Bool
    let isWrong: Bool
    let isConflicting: Bool
    let isHinted: Bool

    var body: some View {
        ZStack {
            background
            if value != 0 {
                Text(String(value))
                    .font(.system(size: 500, weight: isGiven ? .semibold : .regular, design: .rounded))
                    .minimumScaleFactor(0.01)
                    .foregroundStyle(digitColor)
                    .padding(2)
            } else if notes != 0 {
                notesGrid
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var background: some View {
        Rectangle().fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isHinted { return Theme.cellHinted }
        if isSelected { return Theme.cellSelected }
        if isWrong || isConflicting { return Theme.cellWrong }
        if isSameDigit { return Theme.cellSameDigit }
        if isPeer { return Theme.cellPeer }
        return Theme.cellBackground
    }

    private var digitColor: Color {
        if isWrong || isConflicting { return Theme.wrongDigit }
        return isGiven ? Theme.givenDigit : Theme.enteredDigit
    }

    private var notesGrid: some View {
        GeometryReader { geometry in
            let side = geometry.size.width / 3
            ForEach(1...9, id: \.self) { digit in
                if notes.contains(digit) {
                    Text(String(digit))
                        .font(.system(size: side * 0.8, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.noteDigit)
                        .frame(width: side, height: side)
                        .position(
                            x: side * (CGFloat((digit - 1) % 3) + 0.5),
                            y: side * (CGFloat((digit - 1) / 3) + 0.5))
                }
            }
        }
        .padding(1)
    }

    private var accessibilityLabel: String {
        if value != 0 {
            let kind = isGiven
                ? String(localized: "vorgegeben")
                : String(localized: "eingetragen")
            let wrong = isWrong ? String(localized: ", falsch") : ""
            return "\(value), \(kind)\(wrong)"
        }
        if notes != 0 {
            let list = notes.digits.map(String.init).joined(separator: " ")
            return String(localized: "leer, Notizen \(list)")
        }
        return String(localized: "leer")
    }
}
