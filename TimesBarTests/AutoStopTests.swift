import Testing
import Foundation
@testable import TimesBar

// MARK: - shouldAutoStop helper

/// Fixed reference date: 2024-01-15 18:00:00 local time
private func makeDate(hour: Int, minute: Int = 0, daysOffset: Int = 0) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .current
    // Use a fixed date so tests are deterministic
    var comps = DateComponents(year: 2024, month: 1, day: 15 + daysOffset,
                                hour: hour, minute: minute, second: 0)
    return cal.date(from: comps)!
}

private func stopTime(hour: Int, minute: Int = 0) -> DateComponents {
    DateComponents(hour: hour, minute: minute)
}

@Test func autoStopReturnsFalseWhenNowBeforeStopTime() {
    // Timer started at 09:00, stop time is 19:00, now is 18:59
    let runningSince = makeDate(hour: 9)
    let now          = makeDate(hour: 18, minute: 59)
    #expect(
        TimerStore.shouldAutoStop(
            now: now,
            runningSince: runningSince,
            autoStopTime: stopTime(hour: 19)
        ) == false
    )
}

@Test func autoStopReturnsTrueWhenNowAtOrAfterStopTime() {
    // Timer started at 09:00, stop time is 19:00, now is 19:01
    let runningSince = makeDate(hour: 9)
    let now          = makeDate(hour: 19, minute: 1)
    #expect(
        TimerStore.shouldAutoStop(
            now: now,
            runningSince: runningSince,
            autoStopTime: stopTime(hour: 19)
        ) == true
    )
}

@Test func autoStopReturnsTrueWhenTimerStartedYesterdayAndNowPastStopTime() {
    // Timer started yesterday at 09:00, stop time is 19:00, now is today 19:05
    let runningSince = makeDate(hour: 9, daysOffset: -1)
    let now          = makeDate(hour: 19, minute: 5)
    #expect(
        TimerStore.shouldAutoStop(
            now: now,
            runningSince: runningSince,
            autoStopTime: stopTime(hour: 19)
        ) == true
    )
}

/// Edge case: timer started exactly at stop time, now exactly at stop time.
/// Returns false because runningSince is NOT strictly before stopTime.
/// (Documented: a timer started at the exact stop time is treated as "just started" and not auto-stopped.)
@Test func autoStopReturnsFalseWhenStartedExactlyAtStopTime() {
    let runningSince = makeDate(hour: 19)
    let now          = makeDate(hour: 19)
    #expect(
        TimerStore.shouldAutoStop(
            now: now,
            runningSince: runningSince,
            autoStopTime: stopTime(hour: 19)
        ) == false
    )
}

@Test func autoStopReturnsFalseWhenStopTimeHasNilHour() {
    let runningSince = makeDate(hour: 9)
    let now          = makeDate(hour: 20)
    // DateComponents with no hour/minute set → nil
    #expect(
        TimerStore.shouldAutoStop(
            now: now,
            runningSince: runningSince,
            autoStopTime: DateComponents()
        ) == false
    )
}

@Test func autoStopReturnsFalseWhenStopTimeHasNilMinute() {
    let runningSince = makeDate(hour: 9)
    let now          = makeDate(hour: 20)
    // Only hour set, minute is nil
    #expect(
        TimerStore.shouldAutoStop(
            now: now,
            runningSince: runningSince,
            autoStopTime: DateComponents(hour: 19)
        ) == false
    )
}
