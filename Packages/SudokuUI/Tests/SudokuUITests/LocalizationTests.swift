import Foundation
import Testing
@testable import SudokuUI
import SudokuKit

/// The store listing promises English, so English has to actually be there.
/// These check the catalogue is found *and* that the keys match what Foundation
/// looks up at runtime — a mismatch fails silently by echoing the German key,
/// which is exactly the kind of bug nobody notices until a review mentions it.
@Suite("Localisation")
struct LocalizationTests {
    /// `String(localized:locale:)` uses `locale` for formatting numbers and
    /// dates — it does *not* choose which language comes back. That is decided by
    /// the bundle's preferred localisations, which a test cannot set. Loading the
    /// `.lproj` directly is the only way to ask a specific language a question.
    static func string(_ key: String, in language: String) -> String {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path)
        else { return "<\(language).lproj fehlt>" }
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    @Test func plainStringsTranslate() {
        #expect(Self.string("Tagesrätsel", in: "en") == "Daily Puzzle")
        #expect(Self.string("Weiterspielen", in: "en") == "Continue")
        #expect(Self.string("Pausiert", in: "en") == "Paused")
    }

    @Test func stringsWithValuesKeepTheirPlaceholders() {
        #expect(Self.string("Ziffer %lld", in: "en") == "Digit %lld")
        #expect(Self.string("Block %lld", in: "en") == "Box %lld")
    }

    /// The interesting case: English puts the pieces in a different order. The
    /// key carries no position numbers — that is the form Swift looks up — while
    /// the translation does, which is what lets it reorder them.
    @Test func aReorderedTranslationFormatsCorrectly() {
        let format = Self.string("Die %lld kann in %@ nur in %@ stehen.", in: "en")
        #expect(format == "The %1$lld can only go in %3$@ within %2$@.")
        let sentence = String(format: format, locale: Locale(identifier: "en"),
                              7, "row 3", "R3C5")
        #expect(sentence == "The 7 can only go in R3C5 within row 3.")
    }

    @Test func germanIsTheSourceAndStaysAsWritten() {
        #expect(Self.string("Tagesrätsel", in: "de") == "Tagesrätsel")
        #expect(Self.string("Die %lld kann in %@ nur in %@ stehen.", in: "de")
            == "Die %lld kann in %@ nur in %@ stehen.")
    }

    /// A key present in one language but not the other means a German word
    /// appearing mid-sentence in an English app.
    @Test func bothLanguagesCoverTheSameKeys() throws {
        func keys(_ language: String) throws -> Set<String> {
            let path = try #require(Bundle.module.path(forResource: language, ofType: "lproj"))
            let file = URL(fileURLWithPath: path).appendingPathComponent("Localizable.strings")
            let contents = try String(contentsOf: file, encoding: .utf8)
            return Set(contents.split(separator: "\n").compactMap { line in
                guard line.hasPrefix("\"") , let end = line.range(of: "\" = ") else { return nil }
                return String(line[line.index(after: line.startIndex)..<end.lowerBound])
            })
        }
        let german = try keys("de")
        let english = try keys("en")
        #expect(german.count >= 70)
        #expect(german == english, "nur in einer Sprache: \(german.symmetricDifference(english))")
    }

    /// Every difficulty and technique the player can see must have a name in both
    /// languages — these are generated from enums, so one added case slips
    /// through unnoticed otherwise.
    @Test func everyDifficultyAndTechniqueHasAName() {
        for difficulty in Difficulty.allCases {
            #expect(!difficulty.localizedName.isEmpty)
            #expect(!difficulty.localizedSubtitle.isEmpty)
        }
        for technique in Technique.allCases {
            #expect(!HintText.name(for: technique).isEmpty)
        }
    }
}
