import Foundation

public struct SavedBurrow: Codable, Equatable {
    public var screenIndex: Int
    public var x: Double
    public var y: Double
    public var pellets: Int

    public init(screenIndex: Int, x: Double, y: Double, pellets: Int) {
        self.screenIndex = screenIndex
        self.x = x
        self.y = y
        self.pellets = pellets
    }
}

public struct HamsterSettings: Codable, Equatable {
    public static let minimumOnScreen = 1
    public static let maximumOnScreen = 8

    public var pace: HamsterPace
    public var onScreenCount: Int
    public var pausedUntil: Date?
    public var launchAtLogin: Bool
    public var explainedAccessibility: Bool
    public var hamsterPointer: Bool
    public var burrows: [SavedBurrow]
    public var shavingCount: Int

    public init(
        pace: HamsterPace = .normal,
        onScreenCount: Int? = nil,
        pausedUntil: Date? = nil,
        launchAtLogin: Bool = false,
        explainedAccessibility: Bool = false,
        hamsterPointer: Bool = true,
        burrows: [SavedBurrow] = [],
        shavingCount: Int = 0
    ) {
        self.pace = pace
        self.onScreenCount = Self.clamped(onScreenCount ?? pace.suggestedOnScreenCount)
        self.pausedUntil = pausedUntil
        self.launchAtLogin = launchAtLogin
        self.explainedAccessibility = explainedAccessibility
        self.hamsterPointer = hamsterPointer
        self.burrows = burrows
        self.shavingCount = shavingCount
    }

    public static func clamped(_ count: Int) -> Int {
        min(maximumOnScreen, max(minimumOnScreen, count))
    }

    private enum CodingKeys: String, CodingKey {
        case pace
        case onScreenCount
        case pausedUntil
        case launchAtLogin
        case explainedAccessibility
        case hamsterPointer
        case burrows
        case shavingCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pace = try container.decodeIfPresent(HamsterPace.self, forKey: .pace) ?? .normal
        self.pace = pace
        // Files saved before the slider only have pace. Keep those.
        let stored = try container.decodeIfPresent(Int.self, forKey: .onScreenCount)
        self.onScreenCount = Self.clamped(stored ?? pace.suggestedOnScreenCount)
        self.pausedUntil = try container.decodeIfPresent(Date.self, forKey: .pausedUntil)
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        self.explainedAccessibility = try container.decodeIfPresent(Bool.self, forKey: .explainedAccessibility) ?? false
        self.hamsterPointer = try container.decodeIfPresent(Bool.self, forKey: .hamsterPointer) ?? true
        self.burrows = try container.decodeIfPresent([SavedBurrow].self, forKey: .burrows) ?? []
        self.shavingCount = try container.decodeIfPresent(Int.self, forKey: .shavingCount) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pace, forKey: .pace)
        try container.encode(onScreenCount, forKey: .onScreenCount)
        try container.encodeIfPresent(pausedUntil, forKey: .pausedUntil)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
        try container.encode(explainedAccessibility, forKey: .explainedAccessibility)
        try container.encode(hamsterPointer, forKey: .hamsterPointer)
        try container.encode(burrows, forKey: .burrows)
        try container.encode(shavingCount, forKey: .shavingCount)
    }

    public func isPaused(at now: Date) -> Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > now
    }
}

public enum SettingsStore {
    public static func load(from url: URL) -> HamsterSettings {
        guard let data = try? Data(contentsOf: url) else {
            return HamsterSettings()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(HamsterSettings.self, from: data)) ?? HamsterSettings()
    }

    public static func save(_ settings: HamsterSettings, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(settings)
        try data.write(to: url)
    }
}
