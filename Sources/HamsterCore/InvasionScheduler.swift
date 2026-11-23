import Foundation

/// Decides when a hamster appears. The app asks it occasionally.
/// It does not draw anything, and it does not run its own timer,
/// so it stays cheap and can be tested without a Mac.
public struct InvasionScheduler {
    public private(set) var pace: HamsterPace
    public private(set) var pausedUntil: Date?
    public private(set) var burrowCount: Int
    public private(set) var wandererCount: Int
    public private(set) var shavingCount: Int
    /// When set, this is how many runners may be on screen at once.
    /// Older schedules leave it nil and use the pace profile.
    public var wandererLimit: Int?
    private var nextAt: [SpawnKind: Date]
    private var opened: Set<SpawnKind>

    public init(
        pace: HamsterPace,
        now: Date,
        burrowCount: Int = 0,
        shavingCount: Int = 0,
        random: inout SplitMix64
    ) {
        self.pace = pace
        self.pausedUntil = nil
        self.burrowCount = max(0, burrowCount)
        self.wandererCount = 0
        self.shavingCount = max(0, shavingCount)
        self.wandererLimit = nil
        self.nextAt = [:]
        self.opened = []
        scheduleMissing(now: now, opening: true, replaceExisting: false, random: &random)
    }

    public func isPaused(at now: Date) -> Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > now
    }

    public func nextFireDate(for kind: SpawnKind) -> Date? {
        nextAt[kind]
    }

    /// When the app should wake up next. Never sooner than a short beat,
    /// so a bug cannot turn this into a tight loop.
    public func nextWake(after now: Date) -> Date {
        if let pausedUntil, pausedUntil > now {
            return pausedUntil
        }
        let upcoming = nextAt.values.filter { $0 > now }
        if let soonest = upcoming.min() {
            return soonest
        }
        if nextAt.values.contains(where: { $0 <= now }) {
            return now
        }
        return now.addingTimeInterval(30)
    }

    public mutating func pause(for interval: TimeInterval, now: Date) {
        pausedUntil = now.addingTimeInterval(max(1, interval))
    }

    public mutating func resume(now: Date, random: inout SplitMix64) {
        pausedUntil = nil
        scheduleMissing(now: now, opening: false, replaceExisting: true, random: &random)
    }

    public mutating func setPace(_ pace: HamsterPace, now: Date, random: inout SplitMix64) {
        self.pace = pace
        if isPaused(at: now) {
            return
        }
        scheduleMissing(now: now, opening: false, replaceExisting: true, random: &random)
    }

    /// Returns the visits that are due. While paused, it returns nothing.
    /// When a pause ends, it spreads the next visits out instead of firing them all at once.
    @discardableResult
    public mutating func tick(now: Date, random: inout SplitMix64) -> [SpawnKind] {
        if let until = pausedUntil {
            if now < until {
                return []
            }
            pausedUntil = nil
            scheduleMissing(now: now, opening: false, replaceExisting: true, random: &random)
            return []
        }

        var due: [SpawnKind] = []
        for kind in SpawnKind.allCases {
            guard let when = nextAt[kind], when <= now else { continue }
            if !hasRoom(kind) {
                nextAt[kind] = nil
                continue
            }
            due.append(kind)
            record(kind)
            opened.insert(kind)
            if hasRoom(kind) {
                let gap = Self.delay(pace: pace, kind: kind, opening: false, random: &random)
                nextAt[kind] = now.addingTimeInterval(gap)
            } else {
                nextAt[kind] = nil
            }
        }
        return due
    }

    public mutating func noteWandererFinished(now: Date, random: inout SplitMix64) {
        wandererCount = max(0, wandererCount - 1)
        guard nextAt[.wanderer] == nil, hasRoom(.wanderer), !isPaused(at: now) else { return }
        let gap = Self.delay(pace: pace, kind: .wanderer, opening: false, random: &random)
        nextAt[.wanderer] = now.addingTimeInterval(gap)
    }

    /// Used when a burrow could not be placed, so the cap is not eaten by an invisible hole.
    public mutating func noteBurrowRejected(now: Date, random: inout SplitMix64) {
        burrowCount = max(0, burrowCount - 1)
        guard nextAt[.burrow] == nil, hasRoom(.burrow), !isPaused(at: now) else { return }
        let gap = Self.delay(pace: pace, kind: .burrow, opening: false, random: &random)
        nextAt[.burrow] = now.addingTimeInterval(gap)
    }

    private func hasRoom(_ kind: SpawnKind) -> Bool {
        let profile = PaceProfile.of(pace)
        switch kind {
        case .popup:
            return true
        case .wanderer:
            let cap = wandererLimit ?? profile.maxWanderers
            return wandererCount < max(1, cap)
        case .burrow:
            return burrowCount < profile.maxBurrows
        case .shavings:
            return shavingCount < profile.maxShavings
        }
    }

    private mutating func record(_ kind: SpawnKind) {
        switch kind {
        case .popup:
            break
        case .wanderer:
            wandererCount += 1
        case .burrow:
            burrowCount += 1
        case .shavings:
            shavingCount += 1
        }
    }

    private mutating func scheduleMissing(
        now: Date,
        opening: Bool,
        replaceExisting: Bool,
        random: inout SplitMix64
    ) {
        for kind in SpawnKind.allCases {
            if !hasRoom(kind) {
                nextAt[kind] = nil
                continue
            }
            if nextAt[kind] != nil && !replaceExisting {
                continue
            }
            let useOpening = opening && !opened.contains(kind)
            let gap = Self.delay(pace: pace, kind: kind, opening: useOpening, random: &random)
            nextAt[kind] = now.addingTimeInterval(gap)
        }
    }

    private static func delay(
        pace: HamsterPace,
        kind: SpawnKind,
        opening: Bool,
        random: inout SplitMix64
    ) -> TimeInterval {
        let profile = PaceProfile.of(pace)
        let range: ClosedRange<Double>
        switch kind {
        case .popup:
            range = opening ? profile.openingPopup : profile.popup
        case .wanderer:
            range = opening ? profile.openingWander : profile.wander
        case .burrow:
            range = opening ? profile.openingBurrow : profile.burrow
        case .shavings:
            range = opening ? profile.openingShavings : profile.shavings
        }
        return random.double(in: range)
    }
}
