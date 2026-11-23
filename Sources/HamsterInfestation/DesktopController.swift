#if os(macOS)
import AppKit
import HamsterCore

/// The corner hamster stays above ordinary app windows so it is visible while
/// Notion or Chrome is open. Burrows stay down on the desktop.
final class DesktopController {
    var onDoubleClick: () -> Void = {}
    var onOptionClick: () -> Void = {}

    private var peekWindow: OverlayWindow?
    private var peekView: PeekView?
    private var burrowWindows: [OverlayWindow] = []
    private var blinkTimer: Timer?
    private var blinking = false
    private var sleeping = false
    private(set) var shavings = 0
    private var burrows: [SavedBurrow] = []
    private var useHamsterCursor = false

    func start(burrows: [SavedBurrow], shavings: Int, sleeping: Bool) {
        self.burrows = burrows
        self.shavings = shavings
        self.sleeping = sleeping
        showPeek()
        rebuildBurrows()
        blinkTimer?.invalidate()
        let timer = Timer(timeInterval: 3.4, repeats: true) { [weak self] _ in
            self?.blink()
        }
        timer.tolerance = 0.4
        blinkTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        peekWindow?.orderOut(nil)
        for window in burrowWindows {
            window.orderOut(nil)
        }
        burrowWindows.removeAll()
    }

    func setSleeping(_ sleeping: Bool) {
        self.sleeping = sleeping
        peekView?.mood = sleeping ? .sleep : .awake
    }

    func addShaving() {
        shavings += 1
        peekView?.shavings = shavings
        placePeek()
    }

    func addBurrow(_ burrow: SavedBurrow) {
        burrows.append(burrow)
        rebuildBurrows()
    }

    func setHamsterCursor(_ enabled: Bool, cursor: NSCursor) {
        useHamsterCursor = enabled
        peekView?.hamsterCursor = enabled ? cursor : nil
        if let peekView, let peekWindow {
            peekWindow.invalidateCursorRects(for: peekView)
        }
    }

    func relayout() {
        placePeek()
        rebuildBurrows()
    }

    private func showPeek() {
        let window = OverlayWindow(
            frame: NSRect(x: 0, y: 0, width: 230, height: 200),
            clickThrough: false,
            level: .floating,
            behavior: WindowLayers.aboveApps,
            acceptsKey: false
        )
        let view = PeekView(frame: window.contentView?.bounds ?? .zero)
        view.postsFrameChangedNotifications = false
        view.shavings = shavings
        view.mood = sleeping ? .sleep : .awake
        view.onDoubleClick = { [weak self] in self?.onDoubleClick() }
        view.onOptionClick = { [weak self] in self?.onOptionClick() }
        window.contentView = view
        peekWindow = window
        peekView = view
        placePeek()
        window.orderFrontRegardless()
        // Launch can reorder windows after we do. Put the corner back on the next turn.
        DispatchQueue.main.async { [weak window] in
            window?.orderFrontRegardless()
        }
    }

    private func placePeek() {
        guard let window = peekWindow, let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let extra = CGFloat(min(shavings, 12)) * 8
        let size = NSSize(width: 240, height: 200 + extra)
        let frame = NSRect(
            x: visible.maxX - size.width - 4,
            y: visible.maxY - size.height - 4,
            width: size.width,
            height: size.height
        )
        window.setFrame(frame, display: true)
        peekView?.frame = NSRect(origin: .zero, size: size)
        peekView?.needsDisplay = true
    }

    private func rebuildBurrows() {
        for window in burrowWindows {
            window.orderOut(nil)
        }
        burrowWindows.removeAll()
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        for burrow in burrows {
            let index = min(max(0, burrow.screenIndex), screens.count - 1)
            let screen = screens[index]
            let visible = screen.visibleFrame
            let size = NSSize(width: 160, height: 110)
            let frame = NSRect(
                x: visible.minX + CGFloat(burrow.x) * max(0, visible.width - size.width),
                y: visible.minY + CGFloat(burrow.y) * max(0, visible.height - size.height),
                width: size.width,
                height: size.height
            )
            let window = OverlayWindow(
                frame: frame,
                clickThrough: true,
                level: WindowLayers.desktop,
                behavior: WindowLayers.onDesktop
            )
            let view = BurrowView(frame: NSRect(origin: .zero, size: size))
            view.pellets = burrow.pellets
            window.contentView = view
            window.orderFrontRegardless()
            burrowWindows.append(window)
        }
        peekWindow?.orderFrontRegardless()
    }

    private func blink() {
        guard !sleeping else { return }
        peekView?.mood = .blink
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            guard let self, !self.sleeping else { return }
            self.peekView?.mood = .awake
        }
    }
}

private enum PeekMood {
    case awake
    case blink
    case sleep
}

private final class PeekView: NSView {
    var mood: PeekMood = .awake {
        didSet { needsDisplay = true }
    }
    var shavings: Int = 0 {
        didSet { needsDisplay = true }
    }
    var hamsterCursor: NSCursor?
    var onDoubleClick: () -> Void = {}
    var onOptionClick: () -> Void = {}

    override func resetCursorRects() {
        if let hamsterCursor {
            addCursorRect(bounds, cursor: hamsterCursor)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            onOptionClick()
            return
        }
        if event.clickCount >= 2 {
            onDoubleClick()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let holeSize = NSSize(width: 210, height: 142)
        let holeRect = NSRect(
            x: bounds.width - holeSize.width + 18,
            y: bounds.height - holeSize.height + 10,
            width: holeSize.width,
            height: holeSize.height
        )
        NSColor(calibratedRed: 0.23, green: 0.16, blue: 0.13, alpha: 1).setFill()
        NSBezierPath(ovalIn: holeRect.insetBy(dx: 46, dy: 34)).fill()

        let sprite: String
        switch mood {
        case .sleep: sprite = Sprite.peekSleep
        case .blink: sprite = Sprite.peekBlink
        case .awake: sprite = Sprite.peek
        }
        let face = ImageStore.image(named: sprite, pointSize: NSSize(width: 118, height: 110))
        face.draw(in: NSRect(x: holeRect.midX - 59, y: holeRect.minY + 22, width: 118, height: 110))

        ImageStore.image(named: Sprite.hole, pointSize: holeSize).draw(in: holeRect)

        let curl = ImageStore.image(named: Sprite.shaving, pointSize: NSSize(width: 34, height: 26))
        let pile = min(shavings, 12)
        for index in 0..<pile {
            let column = index % 5
            let row = index / 5
            curl.draw(in: NSRect(
                x: holeRect.minX + 18 + CGFloat(column) * 24,
                y: max(4, holeRect.minY - 16 - CGFloat(row) * 18),
                width: 34,
                height: 26
            ))
        }
    }
}

private final class BurrowView: NSView {
    var pellets = 2

    override func draw(_ dirtyRect: NSRect) {
        ImageStore.image(named: Sprite.burrow, pointSize: NSSize(width: 132, height: 78))
            .draw(in: NSRect(x: 4, y: 24, width: 132, height: 78))
        let pellet = ImageStore.image(named: Sprite.pellet, pointSize: NSSize(width: 16, height: 12))
        for index in 0..<min(3, max(0, pellets)) {
            pellet.draw(in: NSRect(
                x: 112 + CGFloat(index) * 12,
                y: 16 + CGFloat(index % 2) * 8,
                width: 16,
                height: 12
            ))
        }
    }
}
#endif
