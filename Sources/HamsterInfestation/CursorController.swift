#if os(macOS)
import AppKit
import HamsterCore

/// Draws a hamster at the pointer.
///
/// The real pointer is hidden only after Accessibility is on and a mouse move
/// has actually arrived, so the pointer can never disappear with nothing to replace it.
/// Pause, quit, and a lost permission put the real pointer back.
final class CursorController {
    var wantsHamsterPointer = true
    var paused = false
    var terminating = false

    private var follower: OverlayWindow?
    private var globalMouse: Any?
    private var localMouse: Any?
    private var receivedGlobalMouseMove = false
    private var hiddenDisplays: [CGDirectDisplayID] = []
    private let pointSize = NSSize(width: 40, height: 40)
    /// Paw-tip hotspot, from the top-left, in points.
    /// The picture is 180 pixels and shown at 40 points, and the claw is at pixel (20, 18).
    /// scripts/render_lifelike.py keeps those two numbers together.
    private let hotX: CGFloat = 20.0 * 40.0 / 180.0
    private let hotFromTop: CGFloat = 18.0 * 40.0 / 180.0

    func start() {
        installMonitorsIfNeeded()
        apply()
    }

    func stop() {
        terminating = true
        apply()
        if let globalMouse {
            NSEvent.removeMonitor(globalMouse)
        }
        if let localMouse {
            NSEvent.removeMonitor(localMouse)
        }
        globalMouse = nil
        localMouse = nil
    }

    var usesHamsterOnOurWindows: Bool {
        CursorPolicy.decide(
            accessibilityTrusted: AccessibilityHelp.isTrusted,
            receivedGlobalMouseMove: receivedGlobalMouseMove,
            wantsHamsterPointer: wantsHamsterPointer,
            paused: paused,
            terminating: terminating
        ).useHamsterOnOurWindows
    }

    func hamsterCursor() -> NSCursor {
        let image = ImageStore.image(named: Sprite.cursor, pointSize: pointSize)
        return NSCursor(image: image, hotSpot: NSPoint(x: hotX, y: hotFromTop))
    }

    func apply() {
        installMonitorsIfNeeded()
        let decision = CursorPolicy.decide(
            accessibilityTrusted: AccessibilityHelp.isTrusted,
            receivedGlobalMouseMove: receivedGlobalMouseMove,
            wantsHamsterPointer: wantsHamsterPointer,
            paused: paused,
            terminating: terminating
        )
        if decision.showFollower {
            placeFollower(at: NSEvent.mouseLocation)
        } else {
            follower?.orderOut(nil)
        }
        if decision.hideSystemCursor {
            hideSystemCursor()
        } else {
            showSystemCursor()
        }
    }

    /// Call when displays are added or removed, so a new screen is not left with a real pointer.
    func resyncDisplays() {
        let shouldHide = !hiddenDisplays.isEmpty
        showSystemCursor()
        if shouldHide {
            hideSystemCursor()
        }
    }

    func refreshPermission() {
        if !AccessibilityHelp.isTrusted {
            receivedGlobalMouseMove = false
        }
        apply()
    }

    private func installMonitorsIfNeeded() {
        if globalMouse == nil {
            globalMouse = NSEvent.addGlobalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            ) { [weak self] _ in
                self?.noteGlobalMove()
            }
        }
        if localMouse == nil {
            localMouse = NSEvent.addLocalMonitorForEvents(
                matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            ) { [weak self] event in
                self?.placeFollower(at: NSEvent.mouseLocation)
                return event
            }
        }
    }

    private func noteGlobalMove() {
        let first = !receivedGlobalMouseMove
        receivedGlobalMouseMove = true
        placeFollower(at: NSEvent.mouseLocation)
        if first {
            apply()
        }
    }

    private func placeFollower(at location: NSPoint) {
        let decision = CursorPolicy.decide(
            accessibilityTrusted: AccessibilityHelp.isTrusted,
            receivedGlobalMouseMove: receivedGlobalMouseMove,
            wantsHamsterPointer: wantsHamsterPointer,
            paused: paused,
            terminating: terminating
        )
        guard decision.showFollower else { return }
        let origin = NSPoint(
            x: location.x - hotX,
            y: location.y - (pointSize.height - hotFromTop)
        )
        if let window = follower {
            let current = window.frame.origin
            // Skip sub-pixel jitter. The paw stays on the click point; it does not lag behind it.
            if abs(current.x - origin.x) < 0.35 && abs(current.y - origin.y) < 0.35 {
                return
            }
            window.setFrameOrigin(origin)
            return
        }
        let frame = NSRect(origin: origin, size: pointSize)
        let created = OverlayWindow(
            frame: frame,
            clickThrough: true,
            level: WindowLayers.follower,
            behavior: WindowLayers.aboveApps
        )
        let view = NSImageView(frame: NSRect(origin: .zero, size: pointSize))
        view.imageScaling = .scaleProportionallyUpOrDown
        view.image = ImageStore.image(named: Sprite.cursor, pointSize: pointSize)
        created.contentView = view
        created.orderFrontRegardless()
        follower = created
    }

    private func hideSystemCursor() {
        guard hiddenDisplays.isEmpty else { return }
        for id in Self.displayIDs() {
            CGDisplayHideCursor(id)
            hiddenDisplays.append(id)
        }
    }

    private func showSystemCursor() {
        guard !hiddenDisplays.isEmpty else { return }
        for id in hiddenDisplays {
            CGDisplayShowCursor(id)
        }
        hiddenDisplays.removeAll()
    }

    private static func displayIDs() -> [CGDirectDisplayID] {
        var ids: [CGDirectDisplayID] = []
        for screen in NSScreen.screens {
            let key = NSDeviceDescriptionKey(rawValue: "NSScreenNumber")
            if let number = screen.deviceDescription[key] as? NSNumber {
                ids.append(CGDirectDisplayID(number.uint32Value))
            }
        }
        if ids.isEmpty {
            ids.append(CGMainDisplayID())
        }
        return ids
    }
}
#endif
