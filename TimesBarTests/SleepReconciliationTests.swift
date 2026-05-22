import Testing
import Foundation
@testable import TimesBar

// MARK: - shouldPrompt helper

@Test func shouldPromptReturnsFalseWhenSleepStartIsNil() {
    #expect(TimerStore.shouldPrompt(sleepStart: nil, wakeAt: Date()) == false)
}

@Test func shouldPromptReturnsFalseWhenSleepDurationBelowThreshold() {
    let sleep = Date()
    let wake  = sleep.addingTimeInterval(599) // 9m 59s — just under 10 minutes
    #expect(TimerStore.shouldPrompt(sleepStart: sleep, wakeAt: wake) == false)
}

@Test func shouldPromptReturnsTrueWhenSleepDurationMeetsThreshold() {
    let sleep = Date()
    let wake  = sleep.addingTimeInterval(600) // exactly 10 minutes
    #expect(TimerStore.shouldPrompt(sleepStart: sleep, wakeAt: wake) == true)
}

@Test func shouldPromptReturnsTrueWhenSleepDurationExceedsThreshold() {
    let sleep = Date()
    let wake  = sleep.addingTimeInterval(3_600) // 1 hour
    #expect(TimerStore.shouldPrompt(sleepStart: sleep, wakeAt: wake) == true)
}

// MARK: - Backdate stop date math

@Test func backdateStopEndEqualsRecordedSleepStart() {
    let sleepStart = Date(timeIntervalSinceReferenceDate: 1_000_000)
    let wakeAt     = sleepStart.addingTimeInterval(3_600)

    let rec = TimerStore.SleepReconciliation(
        runningEntryId: 42,
        sleepStart: sleepStart,
        wakeAt: wakeAt,
        project: 1,
        activity: 2,
        description: "test",
        tags: [])

    // The end date for "backdate stop" must exactly equal the recorded sleepStart.
    #expect(rec.sleepStart == sleepStart)
}
