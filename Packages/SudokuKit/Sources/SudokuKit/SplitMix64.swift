/// A deterministic, seedable pseudo-random generator.
///
/// The whole seed-based design depends on this: the system generator would make
/// puzzles unreproducible, which would break both cross-device sync and the
/// shared daily puzzle. SplitMix64 is small, fast and well distributed.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// FNV-1a over UTF-8 — used to derive stable seeds from strings (e.g. the daily puzzle).
public func fnv1a64(_ string: String) -> UInt64 {
    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
    for byte in string.utf8 {
        hash ^= UInt64(byte)
        hash &*= 0x0000_0100_0000_01B3
    }
    return hash
}
