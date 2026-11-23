#if os(macOS)
import AppKit

/// Picture names inside the app are bland on purpose.
/// The legend lives here, in the project, not in the file name a person sees.
enum Sprite {
    static let cursor = "ui-cursor"
    static let peek = "ui-peek"
    static let peekBlink = "ui-peek-blink"
    static let peekSleep = "ui-peek-sleep"
    static let sad = "ui-sad"
    static let hole = "ui-hole"
    static let shaving = "ui-shaving"
    static let pellet = "ui-pellet"
    static let burrow = "ui-burrow"
    static let popupGIF = "ui-popup"

    static func run(_ index: Int) -> String { "ui-run-\(abs(index) % 6)" }
    static func wave(_ index: Int) -> String { "ui-wave-\(abs(index) % 4)" }
}

enum ImageStore {
    private static var cache: [String: NSImage] = [:]

    static func image(named name: String, pointSize: NSSize) -> NSImage {
        let key = "\(name)-\(Int(pointSize.width))x\(Int(pointSize.height))"
        if let cached = cache[key] {
            return cached
        }
        let loaded = loadPNG(named: name) ?? FallbackArt.image(pointSize: pointSize)
        loaded.size = pointSize
        loaded.isTemplate = false
        cache[key] = loaded
        return loaded
    }

    private static var flippedRuns: [Int: NSImage] = [:]

    static func flippedRunFrame(_ index: Int, pointSize: NSSize) -> NSImage {
        let slot = abs(index) % 6
        if let cached = flippedRuns[slot] {
            return cached
        }
        let image = self.image(named: Sprite.run(slot), pointSize: pointSize)
        let flipped = flip(image)
        flippedRuns[slot] = flipped
        return flipped
    }

    static func flip(_ image: NSImage) -> NSImage {
        let size = image.size
        return NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current else { return false }
            context.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: rect.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            image.draw(in: rect)
            context.restoreGraphicsState()
            return true
        }
    }

    /// Frames for the little visiting card. Uses the GIF when it is in the bundle,
    /// and the still frames when it is not.
    static func popupFrames(pointSize: NSSize) -> [NSImage] {
        if let url = url(for: Sprite.popupGIF, ext: "gif"),
           let data = try? Data(contentsOf: url),
           let rep = NSBitmapImageRep(data: data) {
            let count = max(1, rep.value(forProperty: .frameCount) as? Int ?? 1)
            var frames: [NSImage] = []
            for index in 0..<count {
                rep.setProperty(.currentFrame, withValue: NSNumber(value: index))
                guard let cgImage = rep.cgImage else { continue }
                let image = NSImage(cgImage: cgImage, size: pointSize)
                frames.append(image)
            }
            if !frames.isEmpty {
                return frames
            }
        }
        return (0..<4).map { image(named: Sprite.wave($0), pointSize: pointSize) }
    }

    private static func loadPNG(named name: String) -> NSImage? {
        guard let url = url(for: name, ext: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    private static func url(for name: String, ext: String) -> URL? {
        let file = "\(name).\(ext)"
        for directory in searchDirectories() {
            let url = directory.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private static func searchDirectories() -> [URL] {
        var urls: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL)
        }
        if let executable = Bundle.main.executableURL {
            let macOSFolder = executable.deletingLastPathComponent()
            let contents = macOSFolder.deletingLastPathComponent()
            urls.append(contents.appendingPathComponent("Resources", isDirectory: true))
        }
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(current.appendingPathComponent("Sources/HamsterInfestation/Resources", isDirectory: true))
        return urls
    }
}

/// A simple stand-in so a missing picture does not leave an empty window.
enum FallbackArt {
    static func image(pointSize: NSSize) -> NSImage {
        NSImage(size: pointSize, flipped: false) { rect in
            let body = NSBezierPath(ovalIn: rect.insetBy(dx: rect.width * 0.2, dy: rect.height * 0.22))
            NSColor(calibratedRed: 0.90, green: 0.62, blue: 0.28, alpha: 1).setFill()
            body.fill()
            let ear = NSBezierPath(ovalIn: NSRect(
                x: rect.midX - rect.width * 0.22,
                y: rect.maxY - rect.height * 0.38,
                width: rect.width * 0.16,
                height: rect.height * 0.16
            ))
            ear.fill()
            NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: rect.midX - 6, y: rect.midY, width: 5, height: 5)).fill()
            return true
        }
    }
}
#endif
