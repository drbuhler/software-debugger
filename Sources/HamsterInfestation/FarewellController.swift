#if os(macOS)
import AppKit

/// Shown for a moment when the Mac is restarting, shutting down, or logging out.
/// The window ignores the mouse, and the app always lets the restart continue.
final class FarewellController {
    private var window: OverlayWindow?

    func show() {
        if window != nil { return }
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = NSSize(width: 340, height: 300)
        let visible = screen.visibleFrame
        let frame = NSRect(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        let window = OverlayWindow(
            frame: frame,
            clickThrough: true,
            level: .floating,
            behavior: WindowLayers.aboveApps
        )
        window.hasShadow = true
        let view = FarewellView(frame: NSRect(origin: .zero, size: size))
        window.contentView = view
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
        self.window = window
    }
}

private final class FarewellView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let card = NSBezierPath(roundedRect: bounds.insetBy(dx: 8, dy: 8), xRadius: 22, yRadius: 22)
        NSColor(calibratedRed: 1, green: 0.96, blue: 0.90, alpha: 0.97).setFill()
        card.fill()
        NSColor(calibratedRed: 0.45, green: 0.30, blue: 0.16, alpha: 1).setStroke()
        card.lineWidth = 3
        card.stroke()
        ImageStore.image(named: Sprite.sad, pointSize: NSSize(width: 150, height: 150))
            .draw(in: NSRect(x: (bounds.width - 150) / 2, y: 96, width: 150, height: 150))
        let text = "Don't do it!" as NSString
        let font = Theme.font(size: 28, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(calibratedRed: 0.34, green: 0.22, blue: 0.13, alpha: 1),
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: (bounds.width - size.width) / 2, y: 42),
            withAttributes: attributes
        )
    }
}
#endif
