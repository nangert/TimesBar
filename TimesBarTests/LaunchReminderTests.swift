import Testing
import Foundation
@testable import TimesBar

// MARK: - LaunchReminderObserver.shouldFire

@Test func shouldFire_whenAllConditionsMet() {
    let result = LaunchReminderObserver.shouldFire(
        bundleId: "com.microsoft.VSCode",
        isEnabled: true,
        watchedBundleIds: ["com.microsoft.VSCode", "com.apple.dt.Xcode"],
        isTimerRunning: false,
        firedSinceLastTimerStart: false)
    #expect(result == true)
}

@Test func shouldFire_falseWhenFeatureDisabled() {
    let result = LaunchReminderObserver.shouldFire(
        bundleId: "com.microsoft.VSCode",
        isEnabled: false,
        watchedBundleIds: ["com.microsoft.VSCode"],
        isTimerRunning: false,
        firedSinceLastTimerStart: false)
    #expect(result == false)
}

@Test func shouldFire_falseWhenBundleIdNotWatched() {
    let result = LaunchReminderObserver.shouldFire(
        bundleId: "com.spotify.client",
        isEnabled: true,
        watchedBundleIds: ["com.microsoft.VSCode", "com.apple.dt.Xcode"],
        isTimerRunning: false,
        firedSinceLastTimerStart: false)
    #expect(result == false)
}

@Test func shouldFire_falseWhenTimerAlreadyRunning() {
    // Per the design, no nagging while a timer is already running.
    let result = LaunchReminderObserver.shouldFire(
        bundleId: "com.microsoft.VSCode",
        isEnabled: true,
        watchedBundleIds: ["com.microsoft.VSCode"],
        isTimerRunning: true,
        firedSinceLastTimerStart: false)
    #expect(result == false)
}

@Test func shouldFire_falseWhenAlreadyFiredThisInterval() {
    // The debounce: at most one notification per no-timer interval.
    let result = LaunchReminderObserver.shouldFire(
        bundleId: "com.microsoft.VSCode",
        isEnabled: true,
        watchedBundleIds: ["com.microsoft.VSCode"],
        isTimerRunning: false,
        firedSinceLastTimerStart: true)
    #expect(result == false)
}

@Test func shouldFire_canFireAgainAfterReset() {
    // After timerStarted() resets the flag, the next no-timer interval can fire.
    let result1 = LaunchReminderObserver.shouldFire(
        bundleId: "com.microsoft.VSCode",
        isEnabled: true,
        watchedBundleIds: ["com.microsoft.VSCode"],
        isTimerRunning: false,
        firedSinceLastTimerStart: true)
    #expect(result1 == false)

    // Simulate user started a timer (resets the flag), stopped it, opened VSCode again.
    let result2 = LaunchReminderObserver.shouldFire(
        bundleId: "com.microsoft.VSCode",
        isEnabled: true,
        watchedBundleIds: ["com.microsoft.VSCode"],
        isTimerRunning: false,
        firedSinceLastTimerStart: false)
    #expect(result2 == true)
}
