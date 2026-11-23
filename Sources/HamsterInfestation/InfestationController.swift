#if os(macOS)
import AppKit
import HamsterCore

/// Wires the visit schedule to the windows. This is the whole joke.
final class InfestationController: NSObject {
    private(set) var powerOffNoted = false
    private(set) var isUninstalling = false
    private var terminationReplied = false
    var hasRepliedToTermination: Bool { terminationReplied }
    private var farewellPending = false

    private var settings = HamsterSettings()
    private var random = SplitMix64(seed: UInt64(Date().timeIntervalSince1970.bitPattern))
    private var scheduler: InvasionScheduler!
    private var timer: Timer?

    private let cursor = CursorController()
    private let wanderers = WanderController()
    private let popups = PopupController()
    private let desktop = DesktopController()
    private let farewell = FarewellController()
    private let keys = KeyWatch()
    private let settingsWindow = SettingsController()
    private let uninstallWindow = UninstallController()

    func start(openURLs: [URL]) {
        settings = SettingsStore.load(from: AppIdentity.stateFile(home: home))
        let now = Date()
        scheduler = InvasionScheduler(
            pace: settings.pace,
            now: now,
            burrowCount: settings.burrows.count,
            shavingCount: settings.shavingCount,
            random: &random
        )
        if let until = settings.pausedUntil, until > now {
            scheduler.pause(for: until.timeIntervalSince(now), now: now)
        } else {
            settings.pausedUntil = nil
        }

        wire()
        let paused = scheduler.isPaused(at: now)
        cursor.wantsHamsterPointer = settings.hamsterPointer
        cursor.paused = paused
        cursor.start()
        desktop.start(burrows: settings.burrows, shavings: settings.shavingCount, sleeping: paused)
        desktop.setHamsterCursor(cursor.usesHamsterOnOurWindows, cursor: cursor.hamsterCursor())
        keys.start()
        wanderers.onFinished = { [weak self] in
            guard let self else { return }
            self.scheduler.noteWandererFinished(now: Date(), random: &self.random)
            self.armTimer()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(powerOff),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )

        armTimer()
        let wantsUninstall = openURLs.contains { url in
            url.scheme == AppIdentity.urlScheme && (url.host == "uninstall" || url.path == "/uninstall")
        }
        if wantsUninstall {
            settings.explainedAccessibility = true
            save()
            DispatchQueue.main.async { [weak self] in
                self?.uninstallWindow.ask()
            }
        } else if !settings.explainedAccessibility {
            DispatchQueue.main.async { [weak self] in
                self?.settingsWindow.showIntro()
            }
        }
    }

    func handle(urls: [URL]) {
        guard urls.contains(where: { $0.scheme == AppIdentity.urlScheme && ($0.host == "uninstall" || $0.path == "/uninstall") }) else {
            return
        }
        uninstallWindow.ask()
    }

    func prepareForExit() {
        cursor.terminating = true
        cursor.apply()
        cursor.stop()
        keys.stop()
        timer?.invalidate()
    }

    func beginFarewellIfNeeded() -> NSApplication.TerminateReply {
        if terminationReplied {
            return .terminateNow
        }
        if farewellPending {
            return .terminateLater
        }
        farewellPending = true
        farewell.show()
        DispatchQueue.main.asyncAfter(deadline: .now() + FarewellPolicy.displaySeconds) { [weak self] in
            self?.allowTermination()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + FarewellPolicy.safetyCapSeconds) { [weak self] in
            self?.allowTermination()
        }
        return .terminateLater
    }

    func allowTermination() {
        if terminationReplied { return }
        terminationReplied = true
        prepareForExit()
        // Always allow it. This is the only reply the app ever sends.
        NSApp.reply(toApplicationShouldTerminate: true)
    }

    private var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    private func wire() {
        desktop.onDoubleClick = { [weak self] in
            self?.settingsWindow.show()
        }
        desktop.onOptionClick = { [weak self] in
            self?.uninstallWindow.ask()
        }
        keys.onMatch = { [weak self] in
            self?.uninstallWindow.ask()
        }
        settingsWindow.pace = { [weak self] in self?.settings.pace ?? .normal }
        settingsWindow.setPace = { [weak self] pace in self?.updatePace(pace) }
        settingsWindow.isPaused = { [weak self] in
            guard let self else { return false }
            return self.scheduler.isPaused(at: Date())
        }
        settingsWindow.pausedDescription = { "" }
        settingsWindow.togglePause = { [weak self] in self?.togglePause() }
        settingsWindow.launchAtLogin = { [weak self] in self?.settings.launchAtLogin ?? false }
        settingsWindow.setLaunchAtLogin = { [weak self] enabled in self?.updateLogin(enabled) }
        settingsWindow.hamsterPointer = { [weak self] in self?.settings.hamsterPointer ?? true }
        settingsWindow.setHamsterPointer = { [weak self] enabled in self?.updatePointer(enabled) }
        settingsWindow.accessibilityOn = { AccessibilityHelp.isTrusted }
        settingsWindow.requestAccessibility = { [weak self] in
            AccessibilityHelp.askSystem()
            AccessibilityHelp.openSettings()
            self?.keys.installGlobalIfPossible()
            self?.cursor.refreshPermission()
            self?.syncCursorLook()
        }
        settingsWindow.installCommand = { CommandInstaller.install() }
        settingsWindow.uninstall = { [weak self] in self?.uninstallWindow.ask() }
        settingsWindow.quit = { [weak self] in
            self?.prepareForExit()
            NSApp.terminate(nil)
        }
        settingsWindow.markExplained = { [weak self] in
            guard let self, !self.settings.explainedAccessibility else { return }
            self.settings.explainedAccessibility = true
            self.save()
        }
        uninstallWindow.onYes = { [weak self] in
            self?.performUninstall()
        }
    }

    private func updatePace(_ pace: HamsterPace) {
        settings.pace = pace
        scheduler.setPace(pace, now: Date(), random: &random)
        save()
        armTimer()
    }

    private func togglePause() {
        let now = Date()
        if scheduler.isPaused(at: now) {
            settings.pausedUntil = nil
            scheduler.resume(now: now, random: &random)
            desktop.setSleeping(false)
        } else {
            settings.pausedUntil = now.addingTimeInterval(60 * 60)
            scheduler.pause(for: 60 * 60, now: now)
            desktop.setSleeping(true)
        }
        cursor.paused = scheduler.isPaused(at: Date())
        cursor.apply()
        syncCursorLook()
        save()
        armTimer()
        settingsWindow.refresh()
    }

    private func updateLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        LoginItemController.setEnabled(enabled)
        save()
    }

    private func updatePointer(_ enabled: Bool) {
        settings.hamsterPointer = enabled
        cursor.wantsHamsterPointer = enabled
        cursor.apply()
        syncCursorLook()
        save()
    }

    private func syncCursorLook() {
        desktop.setHamsterCursor(cursor.usesHamsterOnOurWindows, cursor: cursor.hamsterCursor())
    }

    private func armTimer() {
        timer?.invalidate()
        let now = Date()
        let wake = scheduler.nextWake(after: now)
        let delay = max(0.4, wake.timeIntervalSince(now))
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.wake()
        }
        timer.tolerance = min(5, delay * 0.1)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func wake() {
        let now = Date()
        let due = scheduler.tick(now: now, random: &random)
        if settings.pausedUntil != nil && !scheduler.isPaused(at: now) {
            settings.pausedUntil = nil
            desktop.setSleeping(false)
            cursor.paused = false
            cursor.apply()
            syncCursorLook()
            save()
            settingsWindow.refresh()
        }
        for kind in due {
            perform(kind)
        }
        cursor.refreshPermission()
        keys.installGlobalIfPossible()
        armTimer()
    }

    private func perform(_ kind: SpawnKind) {
        switch kind {
        case .popup:
            popups.present(line: SpeechLines.line(random: &random))
        case .wanderer:
            if !wanderers.spawn() {
                scheduler.noteWandererFinished(now: Date(), random: &random)
            }
        case .burrow:
            let screenCount = max(1, NSScreen.screens.count)
            if let burrow = BurrowPlanner.place(existing: settings.burrows, screenCount: screenCount, random: &random) {
                settings.burrows.append(burrow)
                desktop.addBurrow(burrow)
                save()
            } else {
                scheduler.noteBurrowRejected(now: Date(), random: &random)
            }
        case .shavings:
            settings.shavingCount += 1
            desktop.addShaving()
            save()
        }
    }

    private func performUninstall() {
        isUninstalling = true
        prepareForExit()
        LoginItemController.disableAll()
        Housekeeping.removeSupportFiles()
        Housekeeping.trashBundleAndExit { [weak self] in
            self?.prepareForExit()
        }
    }

    @objc private func screensChanged() {
        desktop.relayout()
        cursor.resyncDisplays()
        cursor.apply()
    }

    @objc private func powerOff() {
        // This only records that a restart, shutdown, or logout has begun.
        // It does not cancel it.
        powerOffNoted = true
        farewell.show()
    }

    private func save() {
        try? SettingsStore.save(settings, to: AppIdentity.stateFile(home: home))
    }
}
#endif
