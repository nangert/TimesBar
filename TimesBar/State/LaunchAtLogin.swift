import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for the menu-bar toggle.
/// macOS keeps the canonical state — we just register/unregister.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
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
