import Testing
import Foundation
@testable import TimesBar

// MARK: - TimerStore.todayIndex

@Test func todayIndexReturnsMondayAs0() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    // 2026-05-11 is a Monday.
    let monday = cal.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 10))!
    let weekStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11))!
    #expect(TimerStore.todayIndex(weekStart: weekStart, now: monday, calendar: cal) == 0)
}

@Test func todayIndexReturnsSundayAs6() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    // 2026-05-17 is a Sunday.
    let sunday = cal.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 14))!
    let weekStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11))!
    #expect(TimerStore.todayIndex(weekStart: weekStart, now: sunday, calendar: cal) == 6)
}

@Test func todayIndexReturnsWednesdayAs2() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    // 2026-05-13 is a Wednesday.
    let wednesday = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9))!
    let weekStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11))!
    #expect(TimerStore.todayIndex(weekStart: weekStart, now: wednesday, calendar: cal) == 2)
}

// MARK: - TimerStore.todayHoursValue

@Test func todayHoursValueReturnsStoredBucketWhenNoActiveTimer() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    // Use a fixed Wednesday so todayIndex == 2.
    let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10))!
    let weekHours: [Double] = [1.0, 0.0, 2.5, 0.0, 0.0, 0.0, 0.0]
    let result = TimerStore.todayHoursValue(
        weekHours: weekHours,
        activeBegin: nil,
        weekHoursRefreshedAt: now.addingTimeInterval(-5),
        now: now,
        calendar: cal)
    #expect(abs(result - 2.5) < 0.001)
}

@Test func todayHoursValueAddsLiveDeltaForTimerStartedToday() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    // Wednesday 2026-05-13; timer started at 09:00, weekHours refreshed at 09:30,
    // now is 09:40 — live delta = 10 min = 1/6 h.
    let timerBegin    = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9, minute: 0))!
    let refreshedAt   = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9, minute: 30))!
    let now           = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9, minute: 40))!

    // stored bucket at index 2 already includes 0.5 h (the 30 min up to refreshedAt).
    let weekHours: [Double] = [0.0, 0.0, 0.5, 0.0, 0.0, 0.0, 0.0]
    let result = TimerStore.todayHoursValue(
        weekHours: weekHours,
        activeBegin: timerBegin,
        weekHoursRefreshedAt: refreshedAt,
        now: now,
        calendar: cal)
    // Expected: 0.5 + 10/60 = 0.5 + 0.1667 ≈ 0.6667 h
    #expect(abs(result - (0.5 + 10.0 / 60.0)) < 0.001)
}

@Test func todayHoursValueDoesNotAddDeltaForTimerStartedYesterday() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    // Wednesday 2026-05-13; timer started the previous day (Tuesday).
    let timerBegin  = cal.date(from: DateComponents(year: 2026, month: 5, day: 12, hour: 23, minute: 0))!
    let refreshedAt = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9, minute: 0))!
    let now         = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9, minute: 10))!

    let weekHours: [Double] = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    let result = TimerStore.todayHoursValue(
        weekHours: weekHours,
        activeBegin: timerBegin,
        weekHoursRefreshedAt: refreshedAt,
        now: now,
        calendar: cal)
    // Today bucket is 0; timer started yesterday — no live delta added.
    #expect(abs(result - 0.0) < 0.001)
}

@Test func todayHoursValueClampsDeltaForFreshTimerBeforeFirstRefresh() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    // Wednesday 2026-05-13; timer started 5 minutes ago, weekHours never refreshed
    // (weekHoursRefreshedAt == .distantPast). The delta must be clamped to
    // (now − activeBegin) = 5 min, NOT (now − .distantPast) = years of seconds.
    let now        = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10, minute: 5))!
    let timerBegin = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10, minute: 0))!

    // Bucket is empty — no previous entries logged today.
    let weekHours: [Double] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    let result = TimerStore.todayHoursValue(
        weekHours: weekHours,
        activeBegin: timerBegin,
        weekHoursRefreshedAt: .distantPast,
        now: now,
        calendar: cal)
    // Expected: 5 min = 5/60 ≈ 0.0833 h — NOT thousands of hours.
    #expect(abs(result - 5.0 / 60.0) < 0.001)
}

@Test func todayHoursValueReturnsZeroForEmptyWeekHours() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10))!
    let result = TimerStore.todayHoursValue(
        weekHours: [],
        activeBegin: nil,
        weekHoursRefreshedAt: now,
        now: now,
        calendar: cal)
    #expect(result == 0.0)
}
