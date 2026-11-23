#if os(macOS)
import AppKit
import HamsterCore

/// The window opened by double-clicking the corner hamster.
/// The title says Software Debugger. The text says what is actually going on.
final class SettingsController: NSObject, NSWindowDelegate {
    var pace: () -> HamsterPace = { .normal }
    var setPace: (HamsterPace) -> Void = { _ in }
    var isPaused: () -> Bool = { false }
    var pausedDescription: () -> String = { "" }
    var togglePause: () -> Void = {}
    var launchAtLogin: () -> Bool = { false }
    var setLaunchAtLogin: (Bool) -> Void = { _ in }
    var hamsterPointer: () -> Bool = { true }
    var setHamsterPointer: (Bool) -> Void = { _ in }
    var accessibilityOn: () -> Bool = { false }
    var requestAccessibility: () -> Void = {}
    var installCommand: () -> String = { "" }
    var uninstall: () -> Void = {}
    var quit: () -> Void = {}
    var markExplained: () -> Void = {}

    private var window: NSWindow?
    private var intro: NSWindow?
    private var paceSlider: NSSlider?
    private var pauseButton: NSButton?
    private var loginCheck: NSButton?
    private var pointerCheck: NSButton?
    private var accessLabel: NSTextField?
    private var statusLabel: NSTextField?

    func show() {
        intro?.orderOut(nil)
        let window = self.window ?? makeWindow()
        self.window = window
        refresh()
        WindowFront.present(window)
    }

    /// Call again after launch. An accessory app's first ordering is sometimes dropped.
    func reassertIntro() {
        guard let intro, intro.isVisible else { return }
        WindowFront.present(intro)
    }

    func showIntro() {
        if intro != nil || window != nil { return }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppIdentity.displayName
        window.backgroundColor = Theme.cream
        window.isReleasedWhenClosed = false
        window.delegate = self
        let column = ColumnView(frame: NSRect(x: 0, y: 0, width: 460, height: 520))
        column.add(fitted(
            "A very small, very polite takeover.",
            size: 20,
            weight: .bold
        ))
        column.add(fitted(
            "Software Debugger is the costume. Under it, this is a joke called Hamster Infestation. It draws hamsters on the screen. It does not use the network, it does not collect anything, and it never stops a restart.",
            size: 13,
            weight: .regular
        ), gap: 14)
        column.add(fitted(
            "If you allow Accessibility, you can type -hamster in any app and a hamster will ask before leaving. Only the last 8 characters are remembered, which is just long enough to notice that phrase. Nothing you type is saved.",
            size: 13,
            weight: .regular
        ), gap: 14)
        column.add(fitted(
            "You can say no. Option-click the hamster in the corner, or run minus-hamster in Terminal, and they will still pack up.",
            size: 13,
            weight: .regular
        ), gap: 16)
        let ask = button("Ask macOS", action: #selector(introAsk))
        let later = button("Not now", action: #selector(introLater))
        column.add(ask, height: 30)
        column.add(later, height: 30, gap: 0)
        size(column, onto: window)
        window.center()
        intro = window
        WindowFront.present(window)
    }

    func refresh() {
        paceSlider?.doubleValue = pace().index
        if isPaused() {
            pauseButton?.title = "Wake the hamsters"
        } else {
            pauseButton?.title = "Pause hamsters for 1 hour"
        }
        loginCheck?.state = launchAtLogin() ? .on : .off
        pointerCheck?.state = hamsterPointer() ? .on : .off
        if accessibilityOn() {
            accessLabel?.stringValue = "Accessibility is on, so typing -hamster anywhere will ask before removing this."
        } else {
            accessLabel?.stringValue = "Accessibility is off. Typing -hamster only works while this window is in front. Option-click and minus-hamster still work."
        }
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === intro {
            markExplained()
            intro = nil
        }
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppIdentity.displayName
        window.backgroundColor = Theme.cream
        window.isReleasedWhenClosed = false
        let column = ColumnView(frame: NSRect(x: 0, y: 0, width: 480, height: 900))
        column.add(fitted("Software Debugger", size: 22, weight: .bold), gap: 2)
        column.add(fitted("Build 4.2-hmst. The hmst is the hint.", size: 12, weight: .medium, color: Theme.muted), gap: 12)
        column.add(fitted(
            "Hamsters visit the screen. Nothing here is a real debugger, and nothing leaves this Mac. Double-click the corner hamster to open this window again.",
            size: 13,
            weight: .regular
        ), gap: 14)

        column.add(fitted("How often they visit", size: 15, weight: .semibold), gap: 4)
        let slider = NSSlider(value: pace().index, minValue: 0, maxValue: 2, target: self, action: #selector(paceChanged))
        slider.numberOfTickMarks = 3
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = true
        paceSlider = slider
        column.add(slider, height: 28, gap: 2)
        column.add(fitted("Chill          Normal          Chaos", size: 12, weight: .medium, color: Theme.muted), gap: 12)

        let pause = button("Pause hamsters for 1 hour", action: #selector(pauseClicked))
        pauseButton = pause
        column.add(pause, height: 30)

        let pointer = NSButton(checkboxWithTitle: "Hamster pointer", target: self, action: #selector(pointerClicked))
        pointer.font = Theme.font(size: 13, weight: .regular)
        pointerCheck = pointer
        column.add(pointer, height: 22)

        let login = NSButton(checkboxWithTitle: "Start when I log in", target: self, action: #selector(loginClicked))
        login.font = Theme.font(size: 13, weight: .regular)
        loginCheck = login
        column.add(login, height: 22, gap: 12)

        column.add(fitted("Removing it", size: 15, weight: .semibold), gap: 4)
        column.add(fitted(
            "1. Type -hamster anywhere. That needs Accessibility.\n2. In Terminal, run minus-hamster. That does not need Accessibility.\n3. Option-click the hamster peeking from the corner.",
            size: 13,
            weight: .regular
        ), gap: 8)
        let access = fitted("Checking Accessibility…", size: 12, weight: .regular, color: Theme.muted)
        accessLabel = access
        column.add(access, gap: 8)
        column.add(button("Allow Accessibility…", action: #selector(accessClicked)), height: 30)
        column.add(button("Install the minus-hamster command", action: #selector(installClicked)), height: 30)
        column.add(button("Remove Software Debugger…", action: #selector(removeClicked)), height: 30)
        column.add(button("Quit for now", action: #selector(quitClicked)), height: 30, gap: 8)
        let status = fitted(" ", size: 12, weight: .regular, color: Theme.muted)
        statusLabel = status
        column.add(status, gap: 0)

        size(column, onto: window)
        window.center()
        return window
    }

    private func fitted(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor = Theme.ink
    ) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = Theme.font(size: size, weight: weight)
        field.textColor = color
        field.preferredMaxLayoutWidth = 436
        return field
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = Theme.font(size: 13, weight: .semibold)
        return button
    }

    private func size(_ column: ColumnView, onto window: NSWindow) {
        let height = column.usedHeight
        column.frame = NSRect(x: 0, y: 0, width: column.frame.width, height: height)
        window.setContentSize(NSSize(width: column.frame.width, height: height))
        window.contentView = column
    }

    @objc private func paceChanged() {
        guard let paceSlider else { return }
        setPace(HamsterPace(sliderValue: paceSlider.doubleValue))
    }

    @objc private func pauseClicked() {
        togglePause()
        refresh()
    }

    @objc private func pointerClicked() {
        setHamsterPointer(pointerCheck?.state == .on)
    }

    @objc private func loginClicked() {
        setLaunchAtLogin(loginCheck?.state == .on)
        refresh()
    }

    @objc private func accessClicked() {
        requestAccessibility()
        refresh()
    }

    @objc private func installClicked() {
        statusLabel?.stringValue = installCommand()
        if let statusLabel, let column = window?.contentView as? ColumnView {
            let height = statusLabel.sizeThatFits(NSSize(width: 436, height: 400)).height
            statusLabel.frame.size.height = max(18, height)
            column.noteGrowth()
            window?.setContentSize(NSSize(width: column.frame.width, height: column.usedHeight))
        }
    }

    @objc private func removeClicked() {
        uninstall()
    }

    @objc private func quitClicked() {
        quit()
    }

    @objc private func introAsk() {
        markExplained()
        intro?.close()
        requestAccessibility()
    }

    @objc private func introLater() {
        markExplained()
        intro?.close()
    }
}

private final class ColumnView: NSView {
    override var isFlipped: Bool { true }
    private var cursor: CGFloat = 18
    private let pad: CGFloat = 22

    func add(_ view: NSView, height: CGFloat? = nil, gap: CGFloat = 10) {
        let width = bounds.width - pad * 2
        let resolved: CGFloat
        if let height {
            resolved = height
        } else if let field = view as? NSTextField {
            field.preferredMaxLayoutWidth = width
            resolved = max(18, ceil(field.sizeThatFits(NSSize(width: width, height: 2000)).height))
        } else {
            resolved = 24
        }
        view.frame = NSRect(x: pad, y: cursor, width: width, height: resolved)
        addSubview(view)
        cursor += resolved + gap
    }

    var usedHeight: CGFloat { cursor + 16 }

    /// After a status label grows, keep the reported height honest.
    func noteGrowth() {
        var bottom: CGFloat = 18
        for subview in subviews {
            bottom = max(bottom, subview.frame.maxY + 10)
        }
        cursor = bottom
    }
}

enum CommandInstaller {
    static func install() -> String {
        guard let script = loadScript() else {
            return "The command was not inside the app. From the project folder you can run ./scripts/minus-hamster"
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder = home.appendingPathComponent(".local/bin", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(AppIdentity.cliCommandName)
            try script.write(to: destination, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
        } catch {
            return "Could not install the command. From the project folder, run ./scripts/minus-hamster"
        }
        if FileManager.default.isWritableFile(atPath: "/usr/local/bin") {
            let system = URL(fileURLWithPath: "/usr/local/bin/\(AppIdentity.cliCommandName)")
            try? script.write(to: system, atomically: true, encoding: .utf8)
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: system.path)
        }
        return "Installed. In Terminal, run minus-hamster. If the command is not found, add this to your shell and open Terminal again: export PATH=\"$HOME/.local/bin:$PATH\""
    }

    private static func loadScript() -> String? {
        var urls: [URL] = []
        if let resources = Bundle.main.resourceURL {
            urls.append(resources.appendingPathComponent("terminal-command.sh"))
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appendingPathComponent("scripts/\(AppIdentity.cliCommandName)"))
        for url in urls {
            guard let text = try? String(contentsOf: url) else { continue }
            if text.contains("\(AppIdentity.urlScheme)://uninstall") {
                return text
            }
        }
        return nil
    }
}
#endif
