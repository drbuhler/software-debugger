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

/// A push button whose words are painted in ink, not left to a style that can draw an empty circle.
enum LabeledButton {
    static func push(
        _ title: String,
        target: AnyObject,
        action: Selector,
        destructive: Bool = false
    ) -> NSButton {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 220, height: 32))
        button.setButtonType(.momentaryPushIn)
        // .rounded is a text button on older systems and an icon button on newer ones.
        // A square bezel plus an attributed title keeps the words visible either way.
        button.bezelStyle = .regularSquare
        button.isBordered = true
        button.image = nil
        button.imagePosition = .noImage
        button.showsBorderOnlyWhileMouseInside = false
        button.target = target
        button.action = action
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        applyTitle(title, to: button, destructive: destructive)
        if destructive {
            button.bezelColor = NSColor(calibratedRed: 0.86, green: 0.42, blue: 0.36, alpha: 1)
        }
        return button
    }

    static func applyTitle(_ title: String, to button: NSButton, destructive: Bool = false) {
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let color = destructive
            ? NSColor(calibratedRed: 0.35, green: 0.08, blue: 0.06, alpha: 1)
            : Theme.ink
        button.title = title
        button.font = font
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: color,
            ]
        )
    }

    static func applyCheckboxTitle(_ title: String, to button: NSButton) {
        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        button.title = title
        button.font = font
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: Theme.ink,
            ]
        )
    }
}
#endif
