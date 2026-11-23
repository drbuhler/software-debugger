import Foundation

/// Watches a stream of typed characters for one short phrase.
///
/// It keeps only the last few characters, never the whole stream.
/// That is enough to notice "-hamster" and not enough to be a record of what was typed.
public struct TypedSequenceDetector {
    public let target: String
    private var buffer: String

    public init(target: String = AppIdentity.uninstallPhrase) {
        self.target = target
        buffer = ""
    }

    /// How many characters are currently remembered. Never more than `retainedLimit`.
    public var retainedCount: Int { buffer.count }

    public var retainedLimit: Int { target.count }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    /// Adds typed text. Returns true once the phrase has been completed.
    /// The typed characters are not stored anywhere else.
    public mutating func feed(_ input: String) -> Bool {
        guard !target.isEmpty else { return false }
        var matched = false
        for character in input {
            buffer.append(character)
            if buffer.count > target.count {
                buffer.removeFirst(buffer.count - target.count)
            }
            if buffer == target {
                buffer.removeAll(keepingCapacity: true)
                matched = true
            }
        }
        return matched
    }
}
