import Foundation

public struct CursorHandoff: Equatable {
    /// Hide the real pointer only when we can draw a replacement that follows it.
    public var hideSystemCursor: Bool
    /// Draw the hamster at the pointer.
    public var showFollower: Bool
    /// On windows this app itself owns, the pointer can be the hamster even without Accessibility.
    public var useHamsterOnOurWindows: Bool
}

/// The hamster pointer is best-effort.
/// The real pointer is hidden only after a real mouse-move has arrived,
/// and it is put back as soon as the app pauses, quits, or loses permission.
public enum CursorPolicy {
    public static func decide(
        accessibilityTrusted: Bool,
        receivedGlobalMouseMove: Bool,
        wantsHamsterPointer: Bool,
        paused: Bool,
        terminating: Bool
    ) -> CursorHandoff {
        if terminating || paused || !wantsHamsterPointer {
            return CursorHandoff(
                hideSystemCursor: false,
                showFollower: false,
                useHamsterOnOurWindows: wantsHamsterPointer && !terminating && !paused
            )
        }
        let canFollow = accessibilityTrusted && receivedGlobalMouseMove
        return CursorHandoff(
            hideSystemCursor: canFollow,
            showFollower: canFollow,
            useHamsterOnOurWindows: true
        )
    }
}
