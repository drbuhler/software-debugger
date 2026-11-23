import Foundation

public enum SpeechLines {
    public static let all: [String] = [
        "I live here now.",
        "Got any sunflower seeds?",
        "Your desktop is cozy.",
        "I brought friends.",
        "Please don't vacuum.",
        "This is a very small takeover.",
        "Don't tell the cat.",
        "I only chew pretend wood.",
        "Be right back. Or not.",
        "The corner is mine.",
    ]

    public static func line(random: inout SplitMix64) -> String {
        guard !all.isEmpty else { return "" }
        let index = min(all.count - 1, Int(random.unit() * Double(all.count)))
        return all[index]
    }
}
