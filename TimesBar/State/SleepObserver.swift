import AppKit
import Foundation

/// Observes macOS sleep/wake notifications and forwards them to a handler.
@MainActor
final class SleepObserver {
    enum SleepEvent {
        case willSleep(at: Date)
        case didWake(at: Date)
    }

    // nonisolated(unsafe) lets deinit (always nonisolated) remove the observers
    // without a concurrency violation. The tokens are only written once during
    // init and never mutated again, so the opt-out is safe.
    nonisolated(unsafe) private var sleepToken: NSObjectProtocol?
    nonisolated(unsafe) private var wakeToken: NSObjectProtocol?

    init(handler: @escaping @Sendable (SleepEvent) -> Void) {
        let nc = NSWorkspace.shared.notificationCenter

        sleepToken = nc.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            let ts = Date()
            Task { @MainActor in handler(.willSleep(at: ts)) }
        }

        wakeToken = nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            let ts = Date()
            Task { @MainActor in handler(.didWake(at: ts)) }
        }
    }

    deinit {
        let nc = NSWorkspace.shared.notificationCenter
        if let t = sleepToken { nc.removeObserver(t) }
        if let t = wakeToken  { nc.removeObserver(t) }
    }
}
