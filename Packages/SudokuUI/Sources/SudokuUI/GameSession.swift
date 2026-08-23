import Foundation
import Observation
import SudokuKit

/// What a digit press does.
public enum InputMode: String, Sendable, Codable, CaseIterable {
    case digit, note
}

/// When the app tells the player they are wrong.
public enum ErrorChecking: String, Sendable, Codable, CaseIterable {
    /// Mark a wrong digit the moment it is entered.
    case immediate
    /// Say nothing until the grid is full.
    case atEnd
    /// Never — the player checks their own work.
    case off
}

/// One reversible change to the board.
struct Move: Sendable, Codable {
    let cell: Int
    let oldValue: UInt8
    let newValue: UInt8
    let oldNotes: Candidates
    let newNotes: Candidates
    /// Whether this move was counted as a mistake, so undo can take it back.
    let countedMistake: Bool
}

/// A game in progress: the board, the clock, and everything that can be undone.
///
/// Deliberately free of persistence and of SwiftUI — it is a plain observable
/// value type wrapper, so the whole of the game's behaviour can be tested
/// without a view or a database.
@Observable
public final class GameSession {
    public let puzzle: Puzzle
    public private(set) var entries: [UInt8]
    public private(set) var notes: [Candidates]
    public private(set) var mistakes: Int
    public private(set) var hintsUsed: Int
    public private(set) var elapsedSeconds: Int
    public private(set) var startedAt: Date
    public private(set) var completedAt: Date?
    public private(set) var usedAutoCandidates: Bool

    public var selection: Int?
    public var inputMode: InputMode = .digit
    public var errorChecking: ErrorChecking = .immediate
    public private(set) var isPaused = false

    /// The cell the last hint pointed at, for highlighting.
    public private(set) var hint: Deduction?
    /// What the current hint lets the player write, which is not always what the
    /// hint explains — see ``applyHint()``.
    public private(set) var hintPlacement: CellDigit?

    private var undoStack: [Move] = []
    private var redoStack: [Move] = []

    public init(puzzle: Puzzle, startedAt: Date = .now) {
        self.puzzle = puzzle
        self.entries = puzzle.givens.cells
        self.notes = Array(repeating: 0, count: 81)
        self.mistakes = 0
        self.hintsUsed = 0
        self.elapsedSeconds = 0
        self.startedAt = startedAt
        self.usedAutoCandidates = false
    }

    // MARK: - Board

    public func isGiven(_ cell: Int) -> Bool { puzzle.givens[cell] != 0 }

    public var grid: Grid { Grid(cells: entries)! }

    public var isSolved: Bool { entries == puzzle.solution.cells }

    public var filledCount: Int { entries.count { $0 != 0 } }

    /// Digits that are already placed nine times and need no more input.
    public var completedDigits: Candidates {
        var mask: Candidates = 0
        for digit in 1...9 where entries.count(where: { $0 == UInt8(digit) }) == 9 {
            mask |= Candidates.mask(digit)
        }
        return mask
    }

    /// Cells holding a digit that repeats in one of their units — always shown,
    /// because a duplicate is a rule violation rather than a wrong guess.
    public var conflicts: Set<Int> {
        var result: Set<Int> = []
        for cell in 0..<81 where entries[cell] != 0 {
            for peer in Units.peers[cell] where entries[peer] == entries[cell] {
                result.insert(cell)
                result.insert(peer)
            }
        }
        return result
    }

    /// Cells the player filled with something other than the solution. Empty
    /// unless the current error-checking setting reveals them.
    public func wrongCells(revealAll: Bool = false) -> Set<Int> {
        guard errorChecking != .off || revealAll else { return [] }
        guard revealAll || errorChecking == .immediate || filledCount == 81 else { return [] }
        var result: Set<Int> = []
        for cell in 0..<81
        where entries[cell] != 0 && !isGiven(cell) && entries[cell] != puzzle.solution[cell] {
            result.insert(cell)
        }
        return result
    }

    // MARK: - Input

    /// Enters `digit` in the selected cell, or removes it if it is already there.
    public func enter(_ digit: Int, at cell: Int? = nil) {
        guard let target = cell ?? selection, !isGiven(target), !isPaused, completedAt == nil
        else { return }

        if inputMode == .note {
            toggleNote(digit, at: target)
            return
        }

        let old = entries[target]
        let new = old == UInt8(digit) ? 0 : UInt8(digit)   // tapping the same digit clears it
        var countedMistake = false
        if new != 0 && errorChecking == .immediate && new != puzzle.solution[target] {
            mistakes += 1
            countedMistake = true
        }

        apply(Move(cell: target, oldValue: old, newValue: new,
                   oldNotes: notes[target], newNotes: 0,
                   countedMistake: countedMistake))
        if new != 0 { removeNote(digit, fromPeersOf: target) }
        finishIfSolved()
    }

    public func clear(at cell: Int? = nil) {
        guard let target = cell ?? selection, !isGiven(target), !isPaused, completedAt == nil
        else { return }
        guard entries[target] != 0 || notes[target] != 0 else { return }
        apply(Move(cell: target, oldValue: entries[target], newValue: 0,
                   oldNotes: notes[target], newNotes: 0, countedMistake: false))
    }

    private func toggleNote(_ digit: Int, at cell: Int) {
        guard entries[cell] == 0 else { return }
        let old = notes[cell]
        apply(Move(cell: cell, oldValue: 0, newValue: 0,
                   oldNotes: old, newNotes: old ^ Candidates.mask(digit),
                   countedMistake: false))
    }

    /// Fills every empty cell with the candidates that are still possible.
    /// Costs points once — the app is doing bookkeeping the player would
    /// otherwise do by hand.
    public func fillAutoCandidates() {
        guard let board = CandidateBoard(grid) else { return }
        for cell in 0..<81 where entries[cell] == 0 {
            let old = notes[cell]
            let new = board.candidates[cell]
            guard old != new else { continue }
            apply(Move(cell: cell, oldValue: 0, newValue: 0,
                       oldNotes: old, newNotes: new, countedMistake: false))
        }
        usedAutoCandidates = true
    }

    /// Clears `digit` from the notes of every peer — the bookkeeping a player
    /// does by hand after placing a digit.
    private func removeNote(_ digit: Int, fromPeersOf cell: Int) {
        let bit = Candidates.mask(digit)
        for peer in Units.peers[cell] where notes[peer] & bit != 0 {
            apply(Move(cell: peer, oldValue: entries[peer], newValue: entries[peer],
                       oldNotes: notes[peer], newNotes: notes[peer] & ~bit,
                       countedMistake: false),
                  mergeWithPrevious: true)
        }
    }

    // MARK: - Undo

    /// Moves flagged as merged are undone together with the one before them, so
    /// a single undo takes back a placement *and* the note cleanup it caused.
    private var mergedWithPrevious: Set<Int> = []

    private func apply(_ move: Move, mergeWithPrevious: Bool = false) {
        entries[move.cell] = move.newValue
        notes[move.cell] = move.newNotes
        undoStack.append(move)
        if mergeWithPrevious { mergedWithPrevious.insert(undoStack.count - 1) }
        redoStack.removeAll()
        hint = nil
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func undo() {
        guard !isPaused, completedAt == nil else { return }
        repeat {
            guard let move = undoStack.popLast() else { return }
            let merged = mergedWithPrevious.remove(undoStack.count) != nil
            entries[move.cell] = move.oldValue
            notes[move.cell] = move.oldNotes
            if move.countedMistake { mistakes -= 1 }
            redoStack.append(move)
            if !merged { return }
        } while true
    }

    public func redo() {
        guard !isPaused, completedAt == nil, let move = redoStack.popLast() else { return }
        entries[move.cell] = move.newValue
        notes[move.cell] = move.newNotes
        if move.countedMistake { mistakes += 1 }
        undoStack.append(move)
        finishIfSolved()
    }

    // MARK: - Hints

    /// Asks the solver for the next logical step and marks it.
    @discardableResult
    public func requestHint() -> Deduction? {
        guard !isPaused, completedAt == nil else { return nil }
        // Hint from the player's own board, so it follows their work — but only
        // if that work is still correct, otherwise the advice would be nonsense.
        let source = wrongCells(revealAll: true).isEmpty ? grid : puzzle.givens
        guard let found = LogicalSolver.nextHint(source) else { return nil }
        hintsUsed += 1
        hint = found.deduction
        hintPlacement = found.unlocks
        return found.deduction
    }

    /// Places what the current hint leads to.
    ///
    /// Not necessarily what the explanation is about: a step that only rules
    /// candidates out has nothing to write, so what gets placed is the digit that
    /// reasoning opens up. Without this a hint on a hard puzzle just repeats
    /// itself and the game cannot be finished on hints alone.
    public func applyHint() {
        guard let placement = hint?.placements.first ?? hintPlacement else { return }
        let mode = inputMode
        inputMode = .digit
        enter(placement.digit, at: placement.cell)
        inputMode = mode
        hint = nil
        hintPlacement = nil
    }

    public func dismissHint() {
        hint = nil
        hintPlacement = nil
    }

    // MARK: - Clock

    public func tick() {
        guard !isPaused, completedAt == nil else { return }
        elapsedSeconds += 1
    }

    public func pause() { isPaused = true }
    public func resume() { isPaused = false }

    private func finishIfSolved() {
        guard isSolved, completedAt == nil else { return }
        completedAt = startedAt.addingTimeInterval(TimeInterval(elapsedSeconds))
        isPaused = false
    }

    /// Used by ``GameSession/restoreState(entries:notes:elapsedSeconds:mistakes:hintsUsed:usedAutoCandidates:)``.
    func setRestored(
        entries: [UInt8], notes: [Candidates], elapsedSeconds: Int,
        mistakes: Int, hintsUsed: Int, usedAutoCandidates: Bool
    ) {
        self.entries = entries
        self.notes = notes
        self.elapsedSeconds = elapsedSeconds
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.usedAutoCandidates = usedAutoCandidates
        undoStack.removeAll()
        redoStack.removeAll()
        finishIfSolved()
    }

    // MARK: - Result

    /// What the finished game is worth. `streakDays` and `isRepeat` come from
    /// the player's history, which the session does not know about.
    public func record(streakDays: Int = 0, mode: GameMode = .normal, isRepeat: Bool = false) -> SolveRecord {
        SolveRecord(
            difficulty: puzzle.difficulty, seconds: elapsedSeconds, mistakes: mistakes,
            hintsUsed: hintsUsed, usedAutoCandidates: usedAutoCandidates,
            streakDays: streakDays, mode: mode, isRepeat: isRepeat)
    }
}
