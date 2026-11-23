#if os(macOS)
import AppKit

/// Hamsters that run across the screen and then leave.
/// Their windows ignore the mouse, so they never block a click.
final class WanderController {
    var onFinished: () -> Void = {}
    private var movers: [Mover] = []

    var count: Int { movers.count }

    @discardableResult
    func spawn() -> Bool {
        guard let screen = NSScreen.screens.randomElement() else { return false }
        let visible = screen.visibleFrame
        guard visible.width > 40, visible.height > 40 else { return false }
        let goingRight = Bool.random()
        let size = NSSize(width: 220, height: 138)
        let low = visible.minY + 20
        let high = max(low, visible.maxY - size.height - 20)
        let y = low == high ? low : CGFloat.random(in: low...high)
        let startX = goingRight ? visible.minX - size.width - 12 : visible.maxX + 12
        let frame = NSRect(x: startX, y: y, width: size.width, height: size.height)
        let window = OverlayWindow(
            frame: frame,
            clickThrough: true,
            level: .floating,
            behavior: WindowLayers.aboveApps
        )
        let view = NSImageView(frame: NSRect(origin: .zero, size: size))
        view.imageScaling = .scaleProportionallyUpOrDown
        view.image = frameImage(0, goingRight: goingRight, size: size)
        window.contentView = view
        window.orderFrontRegardless()

        let mover = Mover(
            window: window,
            view: view,
            goingRight: goingRight,
            speed: CGFloat.random(in: 120...200),
            baseY: y,
            screen: screen
        )
        movers.append(mover)
        mover.start(image: { [weak self] index, right, pointSize in
            self?.frameImage(index, goingRight: right, size: pointSize) ?? NSImage()
        }, done: { [weak self, weak mover] in
            guard let self, let mover else { return }
            mover.window.orderOut(nil)
            self.movers.removeAll { $0 === mover }
            self.onFinished()
        })
        return true
    }

    func clear() {
        for mover in movers {
            mover.stop()
            mover.window.orderOut(nil)
        }
        movers.removeAll()
    }

    private func frameImage(_ index: Int, goingRight: Bool, size: NSSize) -> NSImage {
        if goingRight {
            return ImageStore.image(named: Sprite.run(index), pointSize: size)
        }
        return ImageStore.flippedRunFrame(index, pointSize: size)
    }
}

private final class Mover {
    let window: OverlayWindow
    let view: NSImageView
    let goingRight: Bool
    let speed: CGFloat
    let baseY: CGFloat
    let screen: NSScreen
    private var timer: Timer?
    private var distance: CGFloat = 0
    private var frameIndex = 0
    private var last = Date()

    init(window: OverlayWindow, view: NSImageView, goingRight: Bool, speed: CGFloat, baseY: CGFloat, screen: NSScreen) {
        self.window = window
        self.view = view
        self.goingRight = goingRight
        self.speed = speed
        self.baseY = baseY
        self.screen = screen
    }

    func start(image: @escaping (Int, Bool, NSSize) -> NSImage, done: @escaping () -> Void) {
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let now = Date()
            let dt = min(0.05, now.timeIntervalSince(self.last))
            self.last = now
            let step = self.speed * CGFloat(dt)
            self.distance += step
            var frame = self.window.frame
            frame.origin.x += self.goingRight ? step : -step
            // The frames already bob the head. This is only a small rise and fall of the whole body.
            frame.origin.y = self.baseY + CGFloat(sin(Double(self.distance / 28))) * 2.5
            self.window.setFrame(frame, display: false)
            let index = Int(self.distance / 12) % Sprite.runFrameCount
            if index != self.frameIndex {
                self.frameIndex = index
                self.view.image = image(index, self.goingRight, frame.size)
            }
            let visible = self.screen.visibleFrame
            let gone = self.goingRight ? frame.minX > visible.maxX + 8 : frame.maxX < visible.minX - 8
            if gone {
                timer.invalidate()
                self.timer = nil
                done()
            }
        }
        timer.tolerance = 0.004
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
#endif
