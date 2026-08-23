import Foundation
import SudokuKit

/// Turns a solver step into a sentence.
///
/// This is the only place that knows words. The engine reports structure —
/// technique, cells, unit — and the wording lives here, where it can be
/// localised without touching any logic. German is the source language; the
/// English catalogue arrives with the localisation pass in Milestone 6.
public enum HintText {
    public static func name(for technique: Technique) -> String {
        switch technique {
        case .nakedSingle: String(localized: "Nacktes Single", bundle: .module)
        case .hiddenSingle: String(localized: "Verstecktes Single", bundle: .module)
        case .lockedCandidates: String(localized: "Eingeschränkte Kandidaten", bundle: .module)
        case .nakedPair: String(localized: "Nacktes Paar", bundle: .module)
        case .hiddenPair: String(localized: "Verstecktes Paar", bundle: .module)
        case .nakedTriple: String(localized: "Nacktes Tripel", bundle: .module)
        case .hiddenTriple: String(localized: "Verstecktes Tripel", bundle: .module)
        case .nakedQuad: String(localized: "Nacktes Quadrupel", bundle: .module)
        case .hiddenQuad: String(localized: "Verstecktes Quadrupel", bundle: .module)
        case .xWing: "X-Wing"
        case .swordfish: "Swordfish"
        case .xyWing: "XY-Wing"
        case .wWing: "W-Wing"
        case .simpleColouring: String(localized: "Einfaches Färben", bundle: .module)
        case .jellyfish: "Jellyfish"
        case .xyzWing: "XYZ-Wing"
        case .forcingChain: String(localized: "Zwangskette", bundle: .module)
        }
    }

    public static func unitName(_ unit: UnitReference) -> String {
        switch unit.kind {
        case .row: String(localized: "Zeile \(unit.number)", bundle: .module)
        case .column: String(localized: "Spalte \(unit.number)", bundle: .module)
        case .box: String(localized: "Block \(unit.number)", bundle: .module)
        }
    }

    public static func cellName(_ cell: Int) -> String {
        String(localized: "Zeile \(Units.rowOf[cell] + 1), Spalte \(Units.columnOf[cell] + 1)", bundle: .module)
    }

    /// A short headline for the hint card.
    public static func headline(for deduction: Deduction) -> String {
        name(for: deduction.technique)
    }

    /// The explanation under the headline.
    /// What an elimination-only step opens up once it has been carried out.
    public static func unlocks(_ placement: CellDigit) -> String {
        String(localized: "Damit lässt sich die \(placement.digit) in \(cellName(placement.cell)) eintragen.",
               bundle: .module)
    }

    public static func explanation(for deduction: Deduction) -> String {
        if let placement = deduction.placements.first {
            let cell = cellName(placement.cell)
            switch deduction.technique {
            case .nakedSingle:
                return String(localized: "In \(cell) ist nur noch die \(placement.digit) möglich.", bundle: .module)
            case .hiddenSingle:
                let unit = deduction.unit.map(unitName) ?? ""
                return String(localized: "Die \(placement.digit) kann in \(unit) nur in \(cell) stehen.", bundle: .module)
            default:
                return String(localized: "Die \(placement.digit) gehört in \(cell).", bundle: .module)
            }
        }
        let count = deduction.eliminations.count
        if let unit = deduction.unit {
            return String(localized: "In \(unitName(unit)) fallen dadurch \(count) Kandidaten weg.", bundle: .module)
        }
        return String(localized: "Dadurch fallen \(count) Kandidaten weg.", bundle: .module)
    }
}

extension Difficulty {
    public var localizedName: String {
        switch self {
        case .easy: String(localized: "Leicht", bundle: .module)
        case .medium: String(localized: "Mittel", bundle: .module)
        case .hard: String(localized: "Schwer", bundle: .module)
        case .expert: String(localized: "Experte", bundle: .module)
        case .evil: String(localized: "Teuflisch", bundle: .module)
        }
    }

    public var localizedSubtitle: String {
        switch self {
        case .easy: String(localized: "Zum Ankommen", bundle: .module)
        case .medium: String(localized: "Ein ruhiger Abend", bundle: .module)
        case .hard: String(localized: "Mehr als Singles nötig", bundle: .module)
        case .expert: String(localized: "Wings und Färben", bundle: .module)
        case .evil: String(localized: "Zwangsketten", bundle: .module)
        }
    }
}
