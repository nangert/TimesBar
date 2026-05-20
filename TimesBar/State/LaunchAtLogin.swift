import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for the menu-bar toggle.
/// macOS keeps the canonical state — we just register/unregister.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// True if the toggle reflects an approval-pending state. macOS may
    /// require the user to click "Allow" in System Settings → Login Items
    /// the first time a sandboxed app registers itself.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("TimesBar: launch-at-login toggle failed: \(error)")
            return false
        }
    }
}
