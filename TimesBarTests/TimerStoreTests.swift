import Testing
import Foundation
@testable import TimesBar

@Test func elapsedStringFormatsHoursMinutesSeconds() {
    #expect(TimerStore.elapsedString(seconds: 0) == "00:00:00")
    #expect(TimerStore.elapsedString(seconds: 59) == "00:00:59")
    #expect(TimerStore.elapsedString(seconds: 3_600) == "01:00:00")
    #expect(TimerStore.elapsedString(seconds: 3_725) == "01:02:05")
}

@Test func weekHoursAggregatesEntriesByWeekday() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    let mondayStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 9))!
    let mondayEnd   = cal.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 11))!
    let wedStart    = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 9))!
    let wedEnd      = cal.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: 10, minute: 30))!

    let entries = [
        TimesheetEntity(id: 1, project: 1, activity: 1, begin: mondayStart, end: mondayEnd, description: nil),
        TimesheetEntity(id: 2, project: 1, activity: 1, begin: wedStart, end: wedEnd, description: nil),
    ]
    let weekStart = cal.date(from: DateComponents(year: 2026, month: 5, day: 11))!
    let hours = TimerStore.weekHours(entries: entries, weekStart: weekStart, calendar: cal)

    #expect(hours.count == 7)
    #expect(abs(hours[0] - 2.0) < 0.001)
    #expect(abs(hours[2] - 1.5) < 0.001)
    #expect(hours[1] == 0.0)
}

@Test func weekHoursTreatsRunningEntryAsEndingNow() {
    var cal = Calendar(identifier: .iso8601)
    cal.timeZone = TimeZone(identifier: "Europe/Vienna")!
    let now = Date()
    let oneHourAgo = now.addingTimeInterval(-3_600)
    let entries = [
        TimesheetEntity(id: 1, project: 1, activity: 1, begin: oneHourAgo, end: nil, description: nil),
    ]
    let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
    let weekStart = cal.date(from: comps)!
    let hours = TimerStore.weekHours(entries: entries, weekStart: weekStart, calendar: cal, now: now)
    let totalHours = hours.reduce(0, +)
    #expect(abs(totalHours - 1.0) < 0.01)
}
