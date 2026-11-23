#if os(macOS)
import AppKit
import ApplicationServices

enum AccessibilityHelp {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt. The wording in that prompt comes from macOS.
    /// Our own window explains it first, in plain language.
    static func askSystem() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let candidates: [String]
        if #available(macOS 13.0, *) {
            candidates = [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            ]
        } else {
            candidates = [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            ]
        }
        for text in candidates {
            guard let url = URL(string: text) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
#endif
