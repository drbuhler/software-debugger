#if os(macOS)
import AppKit
import Darwin
import HamsterCore
import ServiceManagement

/// Optional "open when I log in".
///
/// On macOS 13 and later this uses SMAppService when that call works.
/// On macOS 12, and if the newer call fails, it uses a LaunchAgent in the home folder.
/// Uninstall removes both. Nothing is registered unless the person turns it on.
enum LoginItemController {
    static func isEnabled() -> Bool {
        if launchAgentExists() {
            return true
        }
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval:
                return true
            case .notRegistered, .notFound:
                break
            @unknown default:
                break
            }
        }
        return false
    }

    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    removeLaunchAgent()
                    try SMAppService.mainApp.register()
                    return
                }
                try SMAppService.mainApp.unregister()
                removeLaunchAgent()
                return
            } catch {
                // Fall through to the LaunchAgent. It works on macOS 12 and as a backup.
            }
        }
        if enabled {
            writeLaunchAgent()
        } else {
            removeLaunchAgent()
        }
    }

    static func disableAll() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.unregister()
        }
        removeLaunchAgent()
    }

    private static func launchAgentExists() -> Bool {
        FileManager.default.fileExists(atPath: plistURL().path)
    }

    private static func writeLaunchAgent() {
        guard let bundle = appBundlePath() else { return }
        let url = plistURL()
        let folder = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": AppIdentity.launchAgentLabel,
            "ProgramArguments": ["/usr/bin/open", "-a", bundle],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            return
        }
        try? data.write(to: url)
    }

    private static func removeLaunchAgent() {
        let url = plistURL()
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            let uid = getuid()
            run("/bin/launchctl", ["bootout", "gui/\(uid)/\(AppIdentity.launchAgentLabel)"])
            run("/bin/launchctl", ["unload", path])
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func plistURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent(AppIdentity.launchAgentLabel + ".plist")
    }

    private static func appBundlePath() -> String? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else { return nil }
        return url.path
    }

    private static func run(_ executable: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
#endif
