#if os(macOS)
import AppKit
import CoreServices
import HamsterCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// There is no main nib, so nothing would create this delegate on its own.
    /// Build it here and hand it to the app, or launch silently does nothing.
    private static var shared: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        shared = delegate
        app.delegate = delegate
        app.run()
    }

    private var infestation: InfestationController?
    private var pendingURLs: [URL] = []
    /// Keeps timers from being postponed for minutes while the app has no Dock icon.
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Timing the visits."
        )
        if anotherCopyIsRunning() {
            NSApp.terminate(nil)
            return
        }
        let controller = InfestationController()
        infestation = controller
        let urls = pendingURLs
        pendingURLs.removeAll()
        controller.start(openURLs: urls)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if let infestation {
            infestation.handle(urls: urls)
        } else {
            pendingURLs.append(contentsOf: urls)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if infestation?.hasRepliedToTermination == true {
            return .terminateNow
        }
        infestation?.prepareForExit()
        if infestation?.isUninstalling == true {
            return .terminateNow
        }
        let kind = QuitReasonCodes.kind(forReasonCode: QuitEvent.reasonCode())
        let ending = (infestation?.powerOffNoted ?? false) || kind.isSessionEnding
        if !ending {
            return .terminateNow
        }
        // shouldAllowTermination is always true. Restart is never refused.
        if !FarewellPolicy.shouldAllowTermination(kind: kind) {
            return .terminateNow
        }
        return infestation?.beginFarewellIfNeeded() ?? .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        infestation?.prepareForExit()
    }

    private func anotherCopyIsRunning() -> Bool {
        let own = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: AppIdentity.bundleIdentifier)
        return others.contains { $0.processIdentifier != own }
    }
}

enum QuitEvent {
    static func reasonCode() -> UInt32? {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return nil }
        let keyword = AEKeyword(QuitReasonCodes.quitReasonKeyword)
        guard let descriptor = event.attributeDescriptor(forKeyword: keyword) else { return nil }
        let code = descriptor.enumCodeValue
        if code == 0 { return nil }
        return code
    }
}
#endif
