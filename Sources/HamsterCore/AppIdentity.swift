import Foundation

/// Names used by Hamster Infestation.
///
/// The project, the code, and the comments keep the hamster name.
/// Anything a person sees before the app is open uses the plain names below,
/// so the downloaded file looks like an ordinary utility. "hmst" is the hint.
public enum AppIdentity {
    public static let internalName = "Hamster Infestation"
    public static let displayName = "Software Debugger"
    public static let bundleIdentifier = "com.dionysius.software-debugger"
    public static let executableName = "Software-Debugger-4.2-hmst"
    public static let appFileName = "Software-Debugger-4.2-hmst.app"
    public static let zipFileName = "Software-Debugger-4.2-hmst.zip"
    public static let diskFileName = "Software-Debugger-4.2-hmst.dmg"
    public static let urlScheme = "swdebug"
    public static let supportDirectoryName = "Software Debugger"
    public static let launchAgentLabel = "com.dionysius.software-debugger"
    public static let cliCommandName = "minus-hamster"
    public static let uninstallPhrase = "-hamster"
    public static let stateFileName = "state.json"

    public static func supportDirectory(home: URL) -> URL {
        home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(supportDirectoryName, isDirectory: true)
    }

    public static func stateFile(home: URL) -> URL {
        supportDirectory(home: home).appendingPathComponent(stateFileName)
    }

    /// Strings that show up in Finder, System Settings, or the file name.
    /// These must not contain the word hamster.
    public static var publicNames: [String] {
        [
            displayName,
            bundleIdentifier,
            executableName,
            appFileName,
            zipFileName,
            diskFileName,
            urlScheme,
            supportDirectoryName,
            launchAgentLabel,
        ]
    }
}
