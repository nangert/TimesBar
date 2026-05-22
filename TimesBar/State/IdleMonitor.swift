import CoreGraphics
import Foundation

/// Polls the system idle time every 30 seconds and fires `onIdleCrossedThreshold`
/// exactly once per idle session — i.e. when seconds-idle crosses from below to
/// above the configured threshold.
@MainActor
final class IdleMonitor {
    var onIdleCrossedThreshold: (TimeInterval) -> Void = { _ in }

    private var timer: Timer?
    private var previousSecondsIdle: TimeInterval = 0

    func start(threshold: TimeInterval) {
        stop()
        previousSecondsIdle = 0
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll(threshold: threshold) }
        }
        // .common keeps the timer firing while the MenuBarExtra dropdown is open.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Pure edge-crossing helper (unit-tested)

    /// Returns `true` when idle time has crossed from below to above `threshold`
    /// between two consecutive polls.
    nonisolated static func didCrossThreshold(previous: TimeInterval?,
                                              current: TimeInterval,
                                              threshold: TimeInterval) -> Bool {
        guard let previous else { return false }
        return previous < threshold && current >= threshold
    }

    // MARK: - Private

    private func poll(threshold: TimeInterval) {
        // kCGAnyInputEventType is defined as (~0) in CoreGraphics — no Swift enum case.
        let anyInput = CGEventType(rawValue: ~UInt32(0))!
        let current = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: anyInput)

        // User just became active again — reset so the next idle cycle can fire.
        if current < 1 {
            previousSecondsIdle = 0
            return
        }

        if Self.didCrossThreshold(previous: previousSecondsIdle, current: current, threshold: threshold) {
            onIdleCrossedThreshold(current)
        }

        previousSecondsIdle = current
    }
}
