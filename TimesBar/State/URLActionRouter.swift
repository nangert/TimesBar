import AppKit
import Foundation

/// Action a `timesbar://` deep link maps to.
///
/// Matches kimai-clock's scheme vocabulary so Shortcuts / Alfred / Raycast
/// presets that target either app keep working with only a host swap.
enum URLAction: Equatable {
    /// Stop the running timer. No-op if nothing is running.
    case stop
    /// Resume the most recent timesheet via Kimai's `/restart?copy=all`.
    /// No-op if a timer is already running or `recent` is empty.
    case startLast
    /// Mirror the ⌘⌥T hotkey: stop if running, otherwise resume the most
    /// recent entry.
    case toggle
    /// Pause the running timer — stops it and remembers the ID so the menu
    /// bar's Resume affordance can `/restart?copy=all` later.
    case pause
    /// Open the configured Kimai web UI in the user's default browser.
    case openWeb
}

enum URLActionRouter {
    /// Map a `timesbar://…` URL to a `URLAction`. Accepts either host-style
    /// (`timesbar://stop`) or path-style (`timesbar:stop`) variants and is
    /// case-insensitive. Returns `nil` for any unrecognized scheme or action.
    static func parse(_ url: URL) -> URLAction? {
        guard url.scheme?.lowercased() == "timesbar" else { return nil }
        let raw = url.host?.lowercased()
            ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        switch raw {
        case "stop":      return .stop
        case "startlast": return .startLast
        case "toggle":    return .toggle
        case "pause":     return .pause
        case "web":       return .openWeb
        default:          return nil
        }
    }
}

@MainActor
extension TimerStore {
    /// Dispatch a parsed URL action against the live store. Silent no-op for
    /// requests that would violate Kimai's single-active-timer invariant
    /// (e.g. `startLast` while a timer is already running).
    func handle(urlAction action: URLAction) {
        switch action {
        case .stop:
            guard isRunning else { return }
            Task { await stop() }
        case .startLast:
            guard !isRunning, let id = recent.first?.id else { return }
            Task { _ = await resumeCheckingResult(timesheetId: id) }
        case .toggle:
            toggleTimer()
        case .pause:
            guard isRunning else { return }
            Task { await pause() }
        case .openWeb:
            NSWorkspace.shared.open(UserPreferences.shared.baseURL)
        }
    }
}
