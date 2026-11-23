import Foundation

public enum HamsterPace: String, Codable, CaseIterable, Equatable {
    case chill
    case normal
    case chaos

    public var title: String {
        switch self {
        case .chill: return "Chill"
        case .normal: return "Normal"
        case .chaos: return "Chaos"
        }
    }

    public var index: Double {
        switch self {
        case .chill: return 0
        case .normal: return 1
        case .chaos: return 2
        }
    }

    public init(sliderValue: Double) {
        switch sliderValue {
        case ..<0.5: self = .chill
        case ..<1.5: self = .normal
        default: self = .chaos
        }
    }

    /// Used when an older settings file has pace but no on-screen count.
    public var suggestedOnScreenCount: Int {
        switch self {
        case .chill: return 1
        case .normal: return 3
        case .chaos: return 6
        }
    }

    public static func matching(onScreenCount count: Int) -> HamsterPace {
        switch count {
        case ...2: return .chill
        case 3...4: return .normal
        default: return .chaos
        }
    }
}

public enum SpawnKind: String, Codable, CaseIterable, Equatable {
    case popup
    case wanderer
    case burrow
    case shavings
}

/// How often things appear, in seconds, and how many can be on screen.
public struct PaceProfile: Equatable {
    public var popup: ClosedRange<Double>
    public var wander: ClosedRange<Double>
    public var burrow: ClosedRange<Double>
    public var shavings: ClosedRange<Double>
    public var openingPopup: ClosedRange<Double>
    public var openingWander: ClosedRange<Double>
    public var openingBurrow: ClosedRange<Double>
    public var openingShavings: ClosedRange<Double>
    public var maxWanderers: Int
    public var maxBurrows: Int
    public var maxShavings: Int

    public static func of(_ pace: HamsterPace) -> PaceProfile {
        switch pace {
        case .chill:
            return PaceProfile(
                popup: 240...420,
                wander: 50...90,
                burrow: 600...900,
                shavings: 180...320,
                openingPopup: 40...70,
                openingWander: 4...10,
                openingBurrow: 50...90,
                openingShavings: 20...40,
                maxWanderers: 1,
                maxBurrows: 3,
                maxShavings: 8
            )
        case .normal:
            return PaceProfile(
                popup: 120...240,
                wander: 22...40,
                burrow: 360...600,
                shavings: 90...160,
                openingPopup: 25...45,
                openingWander: 3...8,
                openingBurrow: 40...70,
                openingShavings: 15...30,
                maxWanderers: 2,
                maxBurrows: 6,
                maxShavings: 14
            )
        case .chaos:
            return PaceProfile(
                popup: 35...70,
                wander: 8...16,
                burrow: 120...240,
                shavings: 40...75,
                openingPopup: 12...25,
                openingWander: 2...5,
                openingBurrow: 20...40,
                openingShavings: 8...16,
                maxWanderers: 4,
                maxBurrows: 12,
                maxShavings: 24
            )
        }
    }
}
