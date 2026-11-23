#if os(macOS)
import AppKit
import HamsterCore

/// Listens for the uninstall phrase.
///
/// Global listening needs Accessibility. The monitor cannot change or swallow
/// keystrokes, and the detector keeps only the last few characters.
final class KeyWatch {
    var onMatch: () -> Void = {}
    private var detector = TypedSequenceDetector()
    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.take(event)
                return event
            }
        }
        installGlobalIfPossible()
    }

    func installGlobalIfPossible() {
        guard globalMonitor == nil, AccessibilityHelp.isTrusted else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.take(event)
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        detector.reset()
    }

    private func take(_ event: NSEvent) {
        if event.isARepeat { return }
        let blocked: NSEvent.ModifierFlags = [.command, .control]
        if !event.modifierFlags.intersection(blocked).isEmpty { return }
        guard let characters = event.characters, !characters.isEmpty else { return }
        if detector.feed(characters) {
            onMatch()
        }
    }
}
#endif
