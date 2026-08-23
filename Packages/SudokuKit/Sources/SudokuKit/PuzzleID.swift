/// The complete recipe for a puzzle: generator version, tier and seed.
///
/// Because generation is deterministic, this 20-odd byte value *is* the puzzle.
/// It is what gets stored and synced; the grid itself is regenerated on demand.
public struct PuzzleID: Sendable, Hashable, Codable, CustomStringConvertible {
    /// Bump this whenever a generator change would alter the puzzle a seed produces.
    /// Older versions must keep working so existing IDs stay valid.
    public static let currentVersion = 2

    public let version: Int
    public let difficulty: Difficulty
    public let seed: UInt64

    public init(difficulty: Difficulty, seed: UInt64, version: Int = PuzzleID.currentVersion) {
        self.version = version
        self.difficulty = difficulty
        self.seed = seed
    }

    /// `v1-expert-3f9a12c40b7e5518`
    public var description: String {
        "v\(version)-\(difficulty.rawValue)-\(String(format: "%016llx", seed))"
    }

    public init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              parts[0].hasPrefix("v"),
              let version = Int(parts[0].dropFirst()),
              let difficulty = Difficulty(rawValue: String(parts[1])),
              let seed = UInt64(parts[2], radix: 16)
        else { return nil }
        self.init(difficulty: difficulty, seed: seed, version: version)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let id = PuzzleID(string) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Not a valid puzzle id: \(string)")
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
