import Foundation

public enum SessionEndReason: String, Equatable, CaseIterable {
    case logOut
    case reallyLogOut
    case restart
    case shutDown
    case restartDialog
}

public enum QuitKind: Equatable {
    case ordinary
    case sessionEnding(SessionEndReason)

    public var isSessionEnding: Bool {
        if case .sessionEnding = self { return true }
        return false
    }
}

/// Apple event codes macOS attaches when the user restarts, shuts down, or logs out.
/// The four-character codes are the public ones from the Apple Event Manager.
public enum QuitReasonCodes {
    public static let quitReasonKeyword: UInt32 = 0x7768793F // 'why?'
    public static let logOut: UInt32 = 0x6C6F676F // 'logo'
    public static let reallyLogOut: UInt32 = 0x726C676F // 'rlgo'
    public static let restart: UInt32 = 0x72657374 // 'rest'
    public static let shutDown: UInt32 = 0x73687574 // 'shut'
    public static let restartDialog: UInt32 = 0x72727374 // 'rrst'

    public static func kind(forReasonCode code: UInt32?) -> QuitKind {
        guard let code else { return .ordinary }
        switch code {
        case logOut:
            return .sessionEnding(.logOut)
        case reallyLogOut:
            return .sessionEnding(.reallyLogOut)
        case restart:
            return .sessionEnding(.restart)
        case shutDown:
            return .sessionEnding(.shutDown)
        case restartDialog:
            return .sessionEnding(.restartDialog)
        default:
            return .ordinary
        }
    }
}

public enum FarewellPolicy {
    /// How long the sad hamster stays up. The restart is allowed when this ends.
    public static let displaySeconds: TimeInterval = 2
    /// A backstop, in case the first timer never runs. Termination is still allowed.
    public static let safetyCapSeconds: TimeInterval = 3.5

    /// Always true. Restart, shutdown, and logout are never refused.
    public static func shouldAllowTermination(kind: QuitKind) -> Bool {
        true
    }
}
