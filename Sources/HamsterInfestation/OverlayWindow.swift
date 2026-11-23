#if os(macOS)
import AppKit

enum WindowLayers {
    /// Above the wallpaper, below normal app windows.
    /// `desktopWindow` itself is often hidden behind the wallpaper on modern macOS,
    /// so the desktop-icon level is the one that actually shows.
    static var desktop: NSWindow.Level {
        NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
    }

    static var follower: NSWindow.Level {
        let cursor = Int(CGWindowLevelForKey(.cursorWindow))
        return NSWindow.Level(rawValue: max(0, cursor - 1))
    }

    static let onDesktop: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .stationary,
        .ignoresCycle,
    ]

    static let aboveApps: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .stationary,
        .ignoresCycle,
        .fullScreenAuxiliary,
    ]
}

/// A borderless window. Click-through windows never take a click from the person.
final class OverlayWindow: NSWindow {
    init(
        frame: NSRect,
        clickThrough: Bool,
        level: NSWindow.Level,
        behavior: NSWindow.CollectionBehavior
    ) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = clickThrough
        self.level = level
        collectionBehavior = behavior
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isMovable = false
    }

    override var canBecomeKey: Bool { !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }
}
#endif
