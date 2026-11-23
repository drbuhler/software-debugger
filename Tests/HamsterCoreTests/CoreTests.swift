import XCTest
@testable import HamsterCore

final class SchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testOpeningDelaysStayInsideTheProfile() {
        for pace in HamsterPace.allCases {
            for seed in [UInt64(1), 2, 3, 9, 42] {
                var random = SplitMix64(seed: seed)
                let scheduler = InvasionScheduler(pace: pace, now: now, random: &random)
                let profile = PaceProfile.of(pace)
                assertDelay(scheduler, .popup, profile.openingPopup, seed: seed, pace: pace)
                assertDelay(scheduler, .wanderer, profile.openingWander, seed: seed, pace: pace)
                assertDelay(scheduler, .burrow, profile.openingBurrow, seed: seed, pace: pace)
                assertDelay(scheduler, .shavings, profile.openingShavings, seed: seed, pace: pace)
            }
        }
    }

    func testChaosIsSoonerThanChill() {
        let chaos = PaceProfile.of(.chaos)
        let chill = PaceProfile.of(.chill)
        XCTAssertLessThan(chaos.popup.upperBound, chill.popup.lowerBound)
        XCTAssertLessThan(chaos.wander.upperBound, chill.wander.lowerBound)
        XCTAssertLessThan(chaos.burrow.upperBound, chill.burrow.lowerBound)
        XCTAssertLessThan(chaos.maxWanderers, 8)
    }

    func testTheVisitAfterTheFirstUsesTheSteadyInterval() throws {
        var random = SplitMix64(seed: 4)
        var scheduler = InvasionScheduler(pace: .chill, now: now, random: &random)
        let first = try XCTUnwrap(scheduler.nextFireDate(for: .popup))
        let tickAt = first.addingTimeInterval(0.01)
        let due = scheduler.tick(now: tickAt, random: &random)
        XCTAssertTrue(due.contains(.popup))
        let next = try XCTUnwrap(scheduler.nextFireDate(for: .popup))
        let gap = next.timeIntervalSince(tickAt)
        let steady = PaceProfile.of(.chill).popup
        XCTAssertGreaterThanOrEqual(gap, steady.lowerBound - 0.001)
        XCTAssertLessThanOrEqual(gap, steady.upperBound + 0.001)
    }

    func testPauseSuppressesVisitsAndDoesNotDumpThemAtTheEnd() throws {
        var random = SplitMix64(seed: 6)
        var scheduler = InvasionScheduler(pace: .normal, now: now, random: &random)
        scheduler.pause(for: 3600, now: now)
        XCTAssertTrue(scheduler.isPaused(at: now.addingTimeInterval(10)))
        XCTAssertTrue(scheduler.tick(now: now.addingTimeInterval(30), random: &random).isEmpty)
        let end = now.addingTimeInterval(3600)
        XCTAssertTrue(scheduler.tick(now: end, random: &random).isEmpty)
        XCTAssertFalse(scheduler.isPaused(at: end))
        for kind in SpawnKind.allCases {
            let fire = try XCTUnwrap(scheduler.nextFireDate(for: kind))
            XCTAssertGreaterThan(fire, end)
        }
    }

    func testCountsNeverExceedTheCap() {
        var moment = now
        var random = SplitMix64(seed: 2)
        var scheduler = InvasionScheduler(pace: .chill, now: moment, random: &random)
        for _ in 0..<40 {
            moment = scheduler.nextWake(after: moment).addingTimeInterval(0.05)
            _ = scheduler.tick(now: moment, random: &random)
        }
        let profile = PaceProfile.of(.chill)
        XCTAssertLessThanOrEqual(scheduler.wandererCount, profile.maxWanderers)
        XCTAssertLessThanOrEqual(scheduler.burrowCount, profile.maxBurrows)
        XCTAssertLessThanOrEqual(scheduler.shavingCount, profile.maxShavings)
        XCTAssertEqual(scheduler.wandererCount, profile.maxWanderers)
        scheduler.noteWandererFinished(now: moment, random: &random)
        XCTAssertEqual(scheduler.wandererCount, profile.maxWanderers - 1)
        XCTAssertNotNil(scheduler.nextFireDate(for: .wanderer))
    }

    func testTheSameSeedMakesTheSameSchedule() {
        XCTAssertEqual(delays(seed: 9), delays(seed: 9))
        XCTAssertNotEqual(delays(seed: 9), delays(seed: 10))
    }

    func testRejectedBurrowDoesNotStickAtTheCap() throws {
        var random = SplitMix64(seed: 1)
        var scheduler = InvasionScheduler(
            pace: .chill,
            now: now,
            burrowCount: PaceProfile.of(.chill).maxBurrows - 1,
            random: &random
        )
        let fire = try XCTUnwrap(scheduler.nextFireDate(for: .burrow))
        _ = scheduler.tick(now: fire.addingTimeInterval(0.01), random: &random)
        XCTAssertEqual(scheduler.burrowCount, PaceProfile.of(.chill).maxBurrows)
        scheduler.noteBurrowRejected(now: fire.addingTimeInterval(0.01), random: &random)
        XCTAssertEqual(scheduler.burrowCount, PaceProfile.of(.chill).maxBurrows - 1)
        XCTAssertNotNil(scheduler.nextFireDate(for: .burrow))
    }

    private func delays(seed: UInt64) -> [String: Double] {
        var random = SplitMix64(seed: seed)
        let scheduler = InvasionScheduler(pace: .normal, now: now, random: &random)
        var result: [String: Double] = [:]
        for kind in SpawnKind.allCases {
            result[kind.rawValue] = scheduler.nextFireDate(for: kind)?.timeIntervalSince(now)
        }
        return result
    }

    private func assertDelay(
        _ scheduler: InvasionScheduler,
        _ kind: SpawnKind,
        _ range: ClosedRange<Double>,
        seed: UInt64,
        pace: HamsterPace
    ) {
        let fire = scheduler.nextFireDate(for: kind)
        XCTAssertNotNil(fire, "\(pace) \(kind) seed \(seed)")
        let gap = fire?.timeIntervalSince(now) ?? -1
        XCTAssertGreaterThanOrEqual(gap, range.lowerBound - 0.001, "\(pace) \(kind) seed \(seed)")
        XCTAssertLessThanOrEqual(gap, range.upperBound + 0.001, "\(pace) \(kind) seed \(seed)")
    }
}

final class TypedSequenceTests: XCTestCase {
    func testExactPhraseMatches() {
        var detector = TypedSequenceDetector()
        XCTAssertFalse(detector.feed("-hamste"))
        XCTAssertTrue(detector.feed("r"))
        XCTAssertEqual(detector.retainedCount, 0)
    }

    func testPhraseInsideOtherTypingMatches() {
        var detector = TypedSequenceDetector()
        XCTAssertTrue(detector.feed("hello -hamster there"))
    }

    func testHamsterWithoutTheDashDoesNotMatch() {
        var detector = TypedSequenceDetector()
        XCTAssertFalse(detector.feed("hamster"))
        XCTAssertFalse(detector.feed("hamsterhamster"))
    }

    func testMatchIsCaseSensitive() {
        var detector = TypedSequenceDetector()
        XCTAssertFalse(detector.feed("-Hamster"))
        XCTAssertFalse(detector.feed("-HAMSTER"))
    }

    func testOverlapStillMatches() {
        var detector = TypedSequenceDetector()
        XCTAssertTrue(detector.feed("-hamste-hamster"))
    }

    func testASecondPhraseCanMatchAfterTheFirst() {
        var detector = TypedSequenceDetector()
        XCTAssertTrue(detector.feed("-hamster"))
        XCTAssertTrue(detector.feed("-hamster"))
    }

    func testTheBufferNeverKeepsMoreThanThePhrase() {
        var detector = TypedSequenceDetector()
        let noise = String(repeating: "a", count: 10_000)
        XCTAssertFalse(detector.feed(noise))
        XCTAssertLessThanOrEqual(detector.retainedCount, detector.retainedLimit)
        XCTAssertEqual(detector.retainedLimit, AppIdentity.uninstallPhrase.count)
        XCTAssertTrue(detector.feed("-hamster"))
        XCTAssertEqual(detector.retainedCount, 0)
    }

    func testEmptyAndPartialInputDoNotMatch() {
        var detector = TypedSequenceDetector()
        XCTAssertFalse(detector.feed(""))
        XCTAssertFalse(detector.feed("-"))
        XCTAssertFalse(detector.feed("ham"))
        detector.reset()
        XCTAssertEqual(detector.retainedCount, 0)
        XCTAssertFalse(detector.feed("-hamXster"))
        XCTAssertTrue(detector.feed("-hamster"))
    }
}

final class UninstallManifestTests: XCTestCase {
    private var home: URL!
    private var bundle: URL!

    override func setUp() {
        home = URL(fileURLWithPath: "/Users/dionysius")
        bundle = URL(fileURLWithPath: "/Applications/Software-Debugger-4.2-hmst.app")
    }

    func testTheListIsTheFilesWeMeanToTouch() {
        let items = UninstallManifest.items(home: home, bundlePath: bundle)
        let paths = items.map(\.path)
        XCTAssertTrue(paths.contains("/Users/dionysius/Library/LaunchAgents/com.dionysius.software-debugger.plist"))
        XCTAssertTrue(paths.contains("/Users/dionysius/Library/Preferences/com.dionysius.software-debugger.plist"))
        XCTAssertTrue(paths.contains("/Users/dionysius/Library/Application Support/Software Debugger"))
        XCTAssertTrue(paths.contains("/Users/dionysius/Library/Caches/com.dionysius.software-debugger"))
        XCTAssertTrue(paths.contains("/Users/dionysius/Library/Saved Application State/com.dionysius.software-debugger.savedState"))
        XCTAssertTrue(paths.contains("/Users/dionysius/.local/bin/minus-hamster"))
        XCTAssertTrue(paths.contains("/usr/local/bin/minus-hamster"))
        XCTAssertTrue(paths.contains(bundle.path))
    }

    func testOnlyTheAppGoesToTheTrash() {
        let items = UninstallManifest.items(home: home, bundlePath: bundle)
        let trashed = items.filter { $0.kind == .moveBundleToTrash }
        XCTAssertEqual(trashed.map(\.path), [bundle.path])
        XCTAssertTrue(trashed.allSatisfy { $0.path.hasSuffix(".app") })
    }

    func testTheListDoesNotDeleteTheHomeFolderOrTheLibraryItself() {
        let items = UninstallManifest.items(home: home, bundlePath: bundle)
        for item in items {
            XCTAssertNotEqual(item.path, "/")
            XCTAssertNotEqual(item.path, home.path)
            XCTAssertNotEqual(item.path, home.path + "/Library")
            XCTAssertFalse(item.path.contains(".."))
            XCTAssertTrue(item.path.hasPrefix("/"))
            XCTAssertTrue(UninstallManifest.isSafe(item, home: home))
        }
    }

    func testARootHomeProducesNothing() {
        let items = UninstallManifest.items(home: URL(fileURLWithPath: "/"), bundlePath: bundle)
        XCTAssertTrue(items.isEmpty)
    }

    func testByHostPreferencesAreAPrefixMatchOnly() {
        let items = UninstallManifest.items(home: home, bundlePath: bundle)
        let prefixed = items.filter(\.matchPrefix)
        XCTAssertEqual(prefixed.count, 1)
        XCTAssertTrue(prefixed[0].path.hasSuffix("/Preferences/ByHost/com.dionysius.software-debugger"))
    }

    func testTheSameInputsProduceTheSameList() {
        let first = UninstallManifest.items(home: home, bundlePath: bundle)
        let second = UninstallManifest.items(home: home, bundlePath: bundle)
        XCTAssertEqual(first, second)
    }

    func testPublicFileNamesDoNotSayHamster() {
        for name in AppIdentity.publicNames {
            XCTAssertNil(name.range(of: "hamster", options: .caseInsensitive), name)
        }
        let items = UninstallManifest.items(home: home, bundlePath: bundle)
        for item in items where !item.path.hasSuffix("/minus-hamster") {
            XCTAssertNil(item.path.range(of: "hamster", options: .caseInsensitive), item.path)
        }
    }
}

final class SafetyTests: XCTestCase {
    func testShutdownIsNeverRefused() {
        XCTAssertTrue(FarewellPolicy.shouldAllowTermination(kind: .ordinary))
        for reason in SessionEndReason.allCases {
            XCTAssertTrue(FarewellPolicy.shouldAllowTermination(kind: .sessionEnding(reason)))
        }
        XCTAssertEqual(FarewellPolicy.displaySeconds, 2)
        XCTAssertGreaterThan(FarewellPolicy.safetyCapSeconds, FarewellPolicy.displaySeconds)
    }

    func testQuitReasonCodes() {
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: nil), .ordinary)
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: 0), .ordinary)
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: 1), .ordinary)
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: QuitReasonCodes.restart), .sessionEnding(.restart))
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: QuitReasonCodes.shutDown), .sessionEnding(.shutDown))
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: QuitReasonCodes.logOut), .sessionEnding(.logOut))
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: QuitReasonCodes.reallyLogOut), .sessionEnding(.reallyLogOut))
        XCTAssertEqual(QuitReasonCodes.kind(forReasonCode: QuitReasonCodes.restartDialog), .sessionEnding(.restartDialog))
        XCTAssertTrue(QuitKind.sessionEnding(.shutDown).isSessionEnding)
        XCTAssertFalse(QuitKind.ordinary.isSessionEnding)
    }

    func testThePointerIsHiddenOnlyWhenItCanBeFollowed() {
        let ready = CursorPolicy.decide(
            accessibilityTrusted: true,
            receivedGlobalMouseMove: true,
            wantsHamsterPointer: true,
            paused: false,
            terminating: false
        )
        XCTAssertTrue(ready.hideSystemCursor)
        XCTAssertTrue(ready.showFollower)

        let noPermission = CursorPolicy.decide(
            accessibilityTrusted: false,
            receivedGlobalMouseMove: true,
            wantsHamsterPointer: true,
            paused: false,
            terminating: false
        )
        XCTAssertFalse(noPermission.hideSystemCursor)
        XCTAssertFalse(noPermission.showFollower)
        XCTAssertTrue(noPermission.useHamsterOnOurWindows)

        let noMoveYet = CursorPolicy.decide(
            accessibilityTrusted: true,
            receivedGlobalMouseMove: false,
            wantsHamsterPointer: true,
            paused: false,
            terminating: false
        )
        XCTAssertFalse(noMoveYet.hideSystemCursor)

        let paused = CursorPolicy.decide(
            accessibilityTrusted: true,
            receivedGlobalMouseMove: true,
            wantsHamsterPointer: true,
            paused: true,
            terminating: false
        )
        XCTAssertFalse(paused.hideSystemCursor)
        XCTAssertFalse(paused.showFollower)

        let quitting = CursorPolicy.decide(
            accessibilityTrusted: true,
            receivedGlobalMouseMove: true,
            wantsHamsterPointer: true,
            paused: false,
            terminating: true
        )
        XCTAssertFalse(quitting.hideSystemCursor)
        XCTAssertFalse(quitting.showFollower)
        XCTAssertFalse(quitting.useHamsterOnOurWindows)
    }

    func testSettingsRoundTrip() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hamster-settings-\(UUID().uuidString)")
        let url = directory.appendingPathComponent("state.json")
        let until = Date(timeIntervalSince1970: 1_800_000_000)
        var settings = HamsterSettings(
            pace: .chaos,
            pausedUntil: until,
            launchAtLogin: true,
            explainedAccessibility: true,
            hamsterPointer: false,
            burrows: [SavedBurrow(screenIndex: 1, x: 0.2, y: 0.3, pellets: 2)],
            shavingCount: 4
        )
        XCTAssertTrue(settings.isPaused(at: until.addingTimeInterval(-5)))
        XCTAssertFalse(settings.isPaused(at: until))
        try? FileManager.default.removeItem(at: directory)
        XCTAssertNoThrow(try SettingsStore.save(settings, to: url))
        let loaded = SettingsStore.load(from: url)
        XCTAssertEqual(loaded.pace, .chaos)
        XCTAssertEqual(loaded.launchAtLogin, true)
        XCTAssertEqual(loaded.hamsterPointer, false)
        XCTAssertEqual(loaded.burrows.count, 1)
        XCTAssertEqual(loaded.shavingCount, 4)
        XCTAssertEqual(loaded.onScreenCount, HamsterPace.chaos.suggestedOnScreenCount)
        XCTAssertEqual(loaded.pausedUntil, until)
        XCTAssertEqual(SettingsStore.load(from: directory.appendingPathComponent("missing.json")).pace, .normal)
        settings.pace = .chill
        try? SettingsStore.save(settings, to: url)
        XCTAssertEqual(SettingsStore.load(from: url).pace, .chill)
        try? FileManager.default.removeItem(at: directory)
    }

    func testOldPaceFileStillChoosesACount() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hamster-old-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("state.json")
        let old = """
        {"burrows":[],"explainedAccessibility":false,"hamsterPointer":true,"launchAtLogin":false,"pace":"chill","shavingCount":0}
        """
        try old.write(to: url, atomically: true, encoding: .utf8)
        let loaded = SettingsStore.load(from: url)
        XCTAssertEqual(loaded.pace, .chill)
        XCTAssertEqual(loaded.onScreenCount, 1)
        XCTAssertEqual(HamsterPace.matching(onScreenCount: 3), .normal)
        XCTAssertEqual(HamsterSettings.clamped(0), 1)
        XCTAssertEqual(HamsterSettings.clamped(40), 8)
        try? FileManager.default.removeItem(at: directory)
    }

    func testBurrowsStayInBoundsAndApart() {
        var random = SplitMix64(seed: 19)
        var placed: [SavedBurrow] = []
        for _ in 0..<8 {
            guard let burrow = BurrowPlanner.place(existing: placed, screenCount: 1, random: &random) else {
                continue
            }
            XCTAssertGreaterThanOrEqual(burrow.x, 0.06)
            XCTAssertLessThanOrEqual(burrow.x, 0.86)
            XCTAssertGreaterThanOrEqual(burrow.y, 0.05)
            XCTAssertLessThanOrEqual(burrow.y, 0.58)
            XCTAssertGreaterThanOrEqual(burrow.pellets, 1)
            XCTAssertLessThanOrEqual(burrow.pellets, 3)
            for other in placed {
                let dx = other.x - burrow.x
                let dy = other.y - burrow.y
                XCTAssertGreaterThanOrEqual(dx * dx + dy * dy, 0.02)
            }
            placed.append(burrow)
        }
        XCTAssertGreaterThanOrEqual(placed.count, 5)
    }

    func testSpeechLinesAreTheOnesWeWrote() {
        var random = SplitMix64(seed: 3)
        for _ in 0..<30 {
            XCTAssertTrue(SpeechLines.all.contains(SpeechLines.line(random: &random)))
        }
    }

    func testPackagingDoesNotAdvertiseHamsters() throws {
        let plist = try String(contentsOf: Repo.root.appendingPathComponent("packaging/Info.plist"), encoding: .utf8)
        XCTAssertNil(plist.range(of: "hamster", options: .caseInsensitive))
        XCTAssertTrue(plist.contains("<string>\(AppIdentity.displayName)</string>"))
        XCTAssertTrue(plist.contains("<string>\(AppIdentity.executableName)</string>"))
        XCTAssertTrue(plist.contains("<string>\(AppIdentity.bundleIdentifier)</string>"))
        XCTAssertTrue(plist.contains("<string>\(AppIdentity.urlScheme)</string>"))
        XCTAssertTrue(plist.contains("<key>LSUIElement</key>"))
        XCTAssertTrue(plist.contains("<key>LSUIElement</key>\n\t<true/>"))
        XCTAssertTrue(plist.contains("<key>LSMinimumSystemVersion</key>\n\t<string>12.0</string>"))
        XCTAssertFalse(plist.contains("NSAppTransportSecurity"))

        let script = try String(contentsOf: Repo.root.appendingPathComponent("scripts/minus-hamster"), encoding: .utf8)
        XCTAssertTrue(script.contains("\(AppIdentity.urlScheme)://uninstall"))
        XCTAssertTrue(script.contains(AppIdentity.appFileName))
        XCTAssertFalse(script.contains("rm "))
        XCTAssertFalse(script.contains("osascript"))
        XCTAssertFalse(script.contains("sudo"))

        let builder = try String(contentsOf: Repo.root.appendingPathComponent("scripts/build-app.sh"), encoding: .utf8)
        XCTAssertTrue(builder.contains("MACOSX_DEPLOYMENT_TARGET"))
        XCTAssertTrue(builder.contains("12.0"))
        XCTAssertTrue(builder.contains(AppIdentity.appFileName.replacingOccurrences(of: ".app", with: "")))
        XCTAssertTrue(builder.contains("dist/${APP_NAME}.app") || builder.contains(AppIdentity.appFileName))
    }

    func testTheUninstallPhraseIsTheAgreedOne() {
        XCTAssertEqual(AppIdentity.uninstallPhrase, "-hamster")
        XCTAssertEqual(AppIdentity.cliCommandName, "minus-hamster")
        XCTAssertEqual(AppIdentity.internalName, "Hamster Infestation")
        XCTAssertEqual(AppIdentity.displayName, "Software Debugger")
    }
}

private enum Repo {
    static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
