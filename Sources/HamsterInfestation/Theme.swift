#if os(macOS)
import AppKit

enum Theme {
    static let ink = NSColor(calibratedRed: 0.32, green: 0.21, blue: 0.13, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.24, alpha: 1)
    static let cream = NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.91, alpha: 1)

    static func font(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = base.fontDescriptor.withDesign(.rounded),
           let rounded = NSFont(descriptor: descriptor, size: size) {
            return rounded
        }
        return base
    }
}
#endif
