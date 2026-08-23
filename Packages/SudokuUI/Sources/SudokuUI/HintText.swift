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
        case .nakedSingle: String(localized: "Nacktes Single")
        case .hiddenSingle: String(localized: "Verstecktes Single")
        case .lockedCandidates: String(localized: "Eingeschränkte Kandidaten")
        case .nakedPair: String(localized: "Nacktes Paar")
        case .hiddenPair: String(localized: "Verstecktes Paar")
        case .nakedTriple: String(localized: "Nacktes Tripel")
        case .hiddenTriple: String(localized: "Verstecktes Tripel")
        case .nakedQuad: String(localized: "Nacktes Quadrupel")
        case .hiddenQuad: String(localized: "Verstecktes Quadrupel")
        case .xWing: "X-Wing"
        case .swordfish: "Swordfish"
        case .xyWing: "XY-Wing"
        case .wWing: "W-Wing"
        case .simpleColouring: String(localized: "Einfaches Färben")
        case .jellyfish: "Jellyfish"
        case .xyzWing: "XYZ-Wing"
        case .forcingChain: String(localized: "Zwangskette")
        }
    }

    public static func unitName(_ unit: UnitReference) -> String {
        switch unit.kind {
        case .row: String(localized: "Zeile \(unit.number)")
        case .column: String(localized: "Spalte \(unit.number)")
        case .box: String(localized: "Block \(unit.number)")
        }
    }

    public static func cellName(_ cell: Int) -> String {
        String(localized: "Zeile \(Units.rowOf[cell] + 1), Spalte \(Units.columnOf[cell] + 1)")
    }

    /// A short headline for the hint card.
    public static func headline(for deduction: Deduction) -> String {
        name(for: deduction.technique)
    }

    /// The explanation under the headline.
    public static func explanation(for deduction: Deduction) -> String {
        if let placement = deduction.placements.first {
            let cell = cellName(placement.cell)
            switch deduction.technique {
            case .nakedSingle:
                return String(localized: "In \(cell) ist nur noch die \(placement.digit) möglich.")
            case .hiddenSingle:
                let unit = deduction.unit.map(unitName) ?? ""
                return String(localized: "Die \(placement.digit) kann in \(unit) nur in \(cell) stehen.")
            default:
                return String(localized: "Die \(placement.digit) gehört in \(cell).")
            }
        }
        let count = deduction.eliminations.count
        if let unit = deduction.unit {
            return String(localized: "In \(unitName(unit)) fallen dadurch \(count) Kandidaten weg.")
        }
        return String(localized: "Dadurch fallen \(count) Kandidaten weg.")
    }
}

extension Difficulty {
    public var localizedName: String {
        switch self {
        case .easy: String(localized: "Leicht")
        case .medium: String(localized: "Mittel")
        case .hard: String(localized: "Schwer")
        case .expert: String(localized: "Experte")
        case .evil: String(localized: "Teuflisch")
        }
    }

    public var localizedSubtitle: String {
        switch self {
        case .easy: String(localized: "Zum Ankommen")
        case .medium: String(localized: "Ein ruhiger Abend")
        case .hard: String(localized: "Mehr als Singles nötig")
        case .expert: String(localized: "Wings und Färben")
        case .evil: String(localized: "Zwangsketten")
        }
    }
}
