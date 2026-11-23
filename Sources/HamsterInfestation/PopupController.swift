#if os(macOS)
import AppKit

/// A small card that fades in, shows a waving hamster, and fades away.
/// It ignores the mouse.
final class PopupController {
    private var window: OverlayWindow?
    private var timer: Timer?
    private var dismissWork: DispatchWorkItem?
    private var frameIndex = 0
    private var frames: [NSImage] = []
    private weak var imageView: NSImageView?

    func present(line: String) {
        guard window == nil else { return }
        guard let screen = NSScreen.screens.randomElement() else { return }
        let size = NSSize(width: 360, height: 188)
        let visible = screen.visibleFrame
        let maxX = max(visible.minX + 8, visible.maxX - size.width - 8)
        let maxY = max(visible.minY + 8, visible.maxY - size.height - 8)
        let origin = NSPoint(
            x: CGFloat.random(in: visible.minX + 8...maxX),
            y: CGFloat.random(in: visible.minY + 8...maxY)
        )
        let frame = NSRect(origin: origin, size: size)
        let window = OverlayWindow(
            frame: frame,
            clickThrough: true,
            level: .floating,
            behavior: WindowLayers.aboveApps
        )
        window.hasShadow = true
        window.alphaValue = 0

        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedRed: 1, green: 0.97, blue: 0.91, alpha: 0.96).cgColor
        root.layer?.cornerRadius = 18
        root.layer?.borderWidth = 2
        root.layer?.borderColor = NSColor(calibratedRed: 0.45, green: 0.30, blue: 0.16, alpha: 1).cgColor

        let pictureSize = NSSize(width: 140, height: 140)
        let picture = NSImageView(frame: NSRect(x: 16, y: 24, width: pictureSize.width, height: pictureSize.height))
        picture.imageScaling = .scaleProportionallyUpOrDown
        frames = ImageStore.popupFrames(pointSize: pictureSize)
        picture.image = frames.first
        imageView = picture
        root.addSubview(picture)

        let text = NSTextField(wrappingLabelWithString: line)
        text.font = Theme.font(size: 16, weight: .semibold)
        text.textColor = NSColor(calibratedRed: 0.34, green: 0.22, blue: 0.13, alpha: 1)
        text.frame = NSRect(x: 168, y: 48, width: 172, height: 92)
        text.alignment = .left
        root.addSubview(text)

        window.contentView = root
        window.orderFrontRegardless()
        self.window = window

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            window.animator().alphaValue = 1
        }

        let timer = Timer(timeInterval: 0.14, repeats: true) { [weak self] _ in
            self?.advanceFrame()
        }
        timer.tolerance = 0.02
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)

        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4, execute: work)
    }

    private func advanceFrame() {
        guard !frames.isEmpty else { return }
        frameIndex = (frameIndex + 1) % frames.count
        imageView?.image = frames[frameIndex]
    }

    private func fadeOut() {
        timer?.invalidate()
        timer = nil
        guard let window else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.7
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.close()
        })
    }

    private func close() {
        timer?.invalidate()
        timer = nil
        dismissWork?.cancel()
        dismissWork = nil
        window?.orderOut(nil)
        window = nil
        frames = []
        frameIndex = 0
    }
}
#endif
