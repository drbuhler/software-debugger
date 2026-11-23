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
    public var pace: HamsterPace
    public var pausedUntil: Date?
    public var launchAtLogin: Bool
    public var explainedAccessibility: Bool
    public var hamsterPointer: Bool
    public var burrows: [SavedBurrow]
    public var shavingCount: Int

    public init(
        pace: HamsterPace = .normal,
        pausedUntil: Date? = nil,
        launchAtLogin: Bool = false,
        explainedAccessibility: Bool = false,
        hamsterPointer: Bool = true,
        burrows: [SavedBurrow] = [],
        shavingCount: Int = 0
    ) {
        self.pace = pace
        self.pausedUntil = pausedUntil
        self.launchAtLogin = launchAtLogin
        self.explainedAccessibility = explainedAccessibility
        self.hamsterPointer = hamsterPointer
        self.burrows = burrows
        self.shavingCount = shavingCount
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
