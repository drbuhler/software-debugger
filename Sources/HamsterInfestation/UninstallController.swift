#if os(macOS)
import AppKit
import HamsterCore

/// Asks "Are you sure you want to delete?" and, on Yes, removes the login item,
/// the settings, and moves the app to the Trash. No is a complete cancel.
final class UninstallController: NSObject, NSWindowDelegate {
    var onYes: () -> Void = {}
    private var window: NSWindow?
    private var asking = false
    private var choice: Choice?

    private enum Choice {
        case yes
        case no
    }

    func ask() {
        if asking { return }
        asking = true
        choice = nil
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppIdentity.displayName
        window.backgroundColor = Theme.cream
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 320))
        let picture = NSImageView(frame: NSRect(x: 170, y: 170, width: 120, height: 120))
        picture.imageScaling = .scaleProportionallyUpOrDown
        picture.image = ImageStore.image(named: Sprite.sad, pointSize: NSSize(width: 120, height: 120))
        content.addSubview(picture)

        let question = NSTextField(labelWithString: "Are you sure you want to delete?")
        question.font = Theme.font(size: 18, weight: .bold)
        question.textColor = Theme.ink
        question.alignment = .center
        question.frame = NSRect(x: 20, y: 118, width: 420, height: 28)
        content.addSubview(question)

        let detail = NSTextField(wrappingLabelWithString: "Yes, delete hamsters moves Software Debugger to the Trash and removes its login item and settings. No, keep them leaves everything as it is.")
        detail.font = Theme.font(size: 13, weight: .regular)
        detail.textColor = Theme.muted
        detail.alignment = .center
        detail.frame = NSRect(x: 28, y: 62, width: 404, height: 52)
        content.addSubview(detail)

        let no = LabeledButton.push("No, keep them", target: self, action: #selector(sayNo))
        no.frame = NSRect(x: 24, y: 16, width: 180, height: 34)
        no.keyEquivalent = "\u{1b}"
        content.addSubview(no)

        let yes = LabeledButton.push("Yes, delete hamsters", target: self, action: #selector(sayYes), destructive: true)
        yes.frame = NSRect(x: 220, y: 16, width: 216, height: 34)
        content.addSubview(yes)

        window.contentView = content
        window.center()
        self.window = window
        WindowFront.present(window)
        let response = NSApp.runModal(for: window)
        window.orderOut(nil)
        self.window = nil
        asking = false
        if response == .OK {
            onYes()
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard choice == nil else { return }
        choice = .no
        NSApp.stopModal(withCode: .cancel)
    }

    @objc private func sayYes() {
        choice = .yes
        NSApp.stopModal(withCode: .OK)
    }

    @objc private func sayNo() {
        choice = .no
        NSApp.stopModal(withCode: .cancel)
    }
}

enum Housekeeping {
    /// Deletes only the files on the uninstall list, except the app bundle.
    static func removeSupportFiles() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let bundle = Bundle.main.bundleURL
        let items = UninstallManifest.items(home: home, bundlePath: bundle)
        let files = FileManager.default
        for item in items where item.kind != .moveBundleToTrash {
            guard UninstallManifest.isSafe(item, home: home) else { continue }
            if item.matchPrefix {
                let url = URL(fileURLWithPath: item.path)
                let directory = url.deletingLastPathComponent()
                let prefix = url.lastPathComponent
                let names = (try? files.contentsOfDirectory(atPath: directory.path)) ?? []
                for name in names where name.hasPrefix(prefix) {
                    let child = directory.appendingPathComponent(name)
                    guard UninstallManifest.isSafe(
                        CleanupItem(path: child.path, kind: .deleteFile, label: item.label),
                        home: home
                    ) else { continue }
                    try? files.removeItem(at: child)
                }
            } else {
                try? files.removeItem(at: URL(fileURLWithPath: item.path))
            }
        }
    }

    /// Moves the app to the Trash after this process has let go of it.
    /// A small helper waits in case the Trash call cannot move a running app.
    static func trashBundleAndExit(restorePointer: @escaping () -> Void) {
        let bundle = Bundle.main.bundleURL
        let pid = ProcessInfo.processInfo.processIdentifier
        spawnMover(pid: pid, bundlePath: bundle.path)
        restorePointer()
        if bundle.pathExtension == "app" {
            NSWorkspace.shared.recycle([bundle]) { _, _ in
                restorePointer()
                exit(0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            restorePointer()
            exit(0)
        }
    }

    private static func spawnMover(pid: Int32, bundlePath: String) {
        let script = """
        #!/bin/bash
        pid="$1"
        app="$2"
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
          if ! kill -0 "$pid" 2>/dev/null; then
            break
          fi
          sleep 1
        done
        if [ -d "$app" ]; then
          mkdir -p "$HOME/.Trash"
          base="$(basename "$app")"
          dest="$HOME/.Trash/$base"
          if [ -e "$dest" ]; then
            dest="$HOME/.Trash/${base%.app}-$(date +%s).app"
          fi
          mv "$app" "$dest"
        fi
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("swdebug-move-\(pid).sh")
        guard (try? script.write(to: url, atomically: true, encoding: .utf8)) != nil else { return }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [url.path, String(pid), bundlePath]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }
}
#endif
