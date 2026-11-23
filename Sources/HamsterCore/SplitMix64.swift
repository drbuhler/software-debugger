import Foundation

/// A tiny deterministic generator so the visit schedule can be tested.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// A number in 0..<1.
    public mutating func unit() -> Double {
        let value = next() >> 11
        return Double(value) / Double(1 << 53)
    }

    public mutating func double(in range: ClosedRange<Double>) -> Double {
        if range.lowerBound >= range.upperBound {
            return range.lowerBound
        }
        let span = range.upperBound - range.lowerBound
        return min(range.upperBound, range.lowerBound + unit() * span)
    }
}
