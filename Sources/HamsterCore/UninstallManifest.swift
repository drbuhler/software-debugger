import Foundation

public enum CleanupKind: String, Equatable {
    case deleteFile
    case deleteDirectory
    /// The app itself is moved to the Trash. It is not shredded in place.
    case moveBundleToTrash
}

public struct CleanupItem: Equatable {
    public var path: String
    public var kind: CleanupKind
    public var label: String
    /// When set, only children of the parent folder whose names start with the last component are removed.
    public var matchPrefix: Bool

    public init(path: String, kind: CleanupKind, label: String, matchPrefix: Bool = false) {
        self.path = path
        self.kind = kind
        self.label = label
        self.matchPrefix = matchPrefix
    }
}

/// The complete list of files removal is allowed to touch.
/// The app deletes this list and nothing else.
public enum UninstallManifest {
    public static func items(home: URL, bundlePath: URL) -> [CleanupItem] {
        let homePath = normalized(home.path)
        // A broken home path must not turn removal into a sweep of the disk.
        if homePath.isEmpty || homePath == "/" {
            return []
        }
        let bundle = normalized(bundlePath.path)
        let id = AppIdentity.bundleIdentifier
        let items = [
            CleanupItem(
                path: homePath + "/Library/LaunchAgents/" + AppIdentity.launchAgentLabel + ".plist",
                kind: .deleteFile,
                label: "login item"
            ),
            CleanupItem(
                path: homePath + "/Library/Preferences/" + id + ".plist",
                kind: .deleteFile,
                label: "preferences"
            ),
            CleanupItem(
                path: homePath + "/Library/Preferences/ByHost/" + id,
                kind: .deleteFile,
                label: "preferences for this Mac",
                matchPrefix: true
            ),
            CleanupItem(
                path: homePath + "/Library/Application Support/" + AppIdentity.supportDirectoryName,
                kind: .deleteDirectory,
                label: "saved state"
            ),
            CleanupItem(
                path: homePath + "/Library/Caches/" + id,
                kind: .deleteDirectory,
                label: "cache"
            ),
            CleanupItem(
                path: homePath + "/Library/Saved Application State/" + id + ".savedState",
                kind: .deleteDirectory,
                label: "saved windows"
            ),
            CleanupItem(
                path: homePath + "/.local/bin/" + AppIdentity.cliCommandName,
                kind: .deleteFile,
                label: "terminal command in your home folder"
            ),
            CleanupItem(
                path: "/usr/local/bin/" + AppIdentity.cliCommandName,
                kind: .deleteFile,
                label: "terminal command"
            ),
            CleanupItem(
                path: bundle,
                kind: .moveBundleToTrash,
                label: "the app"
            ),
        ]
        return items.filter { isSafe($0, homePath: homePath) }
    }

    public static func isSafe(_ item: CleanupItem, home: URL) -> Bool {
        isSafe(item, homePath: normalized(home.path))
    }

    private static func isSafe(_ item: CleanupItem, homePath: String) -> Bool {
        let path = normalized(item.path)
        if path.isEmpty || path.contains("..") {
            return false
        }
        if path == "/" || path == homePath {
            return false
        }
        let protected = [
            homePath + "/Library",
            homePath + "/Library/Application Support",
            homePath + "/Library/Preferences",
            homePath + "/Library/Preferences/ByHost",
            homePath + "/Library/Caches",
            homePath + "/Library/LaunchAgents",
            homePath + "/Library/Saved Application State",
            "/usr/local/bin",
            "/usr/local",
            "/usr",
        ]
        if protected.contains(path) {
            return false
        }
        switch item.kind {
        case .moveBundleToTrash:
            return path.hasSuffix(".app")
        case .deleteFile, .deleteDirectory:
            if path == "/usr/local/bin/" + AppIdentity.cliCommandName {
                return true
            }
            return path.hasPrefix(homePath + "/")
        }
    }

    private static func normalized(_ path: String) -> String {
        var value = path
        while value.contains("//") {
            value = value.replacingOccurrences(of: "//", with: "/")
        }
        while value.count > 1 && value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
