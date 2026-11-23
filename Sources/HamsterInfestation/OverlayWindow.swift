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

/// Brings a real window forward for an app that has no Dock icon.
/// A normal-level window in an accessory app stays behind Chrome and Notion.
enum WindowFront {
    static func activate() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    static func present(_ window: NSWindow) {
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
        activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

/// A borderless window. Click-through windows never take a click from the person.
final class OverlayWindow: NSWindow {
    private let acceptsKey: Bool

    init(
        frame: NSRect,
        clickThrough: Bool,
        level: NSWindow.Level,
        behavior: NSWindow.CollectionBehavior,
        acceptsKey: Bool = true
    ) {
        self.acceptsKey = acceptsKey
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

    override var canBecomeKey: Bool { acceptsKey && !ignoresMouseEvents }
    override var canBecomeMain: Bool { false }
}
#endif
