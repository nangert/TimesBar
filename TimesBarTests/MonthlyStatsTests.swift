import Testing
import Foundation
@testable import TimesBar

/// Tests for `MonthlyBalanceCalculator` — the pure function that powers the
/// Monthly balance page. Lives in `Europe/Vienna` to match the user's setup;
/// the underlying calendar arithmetic is timezone-aware so the asserted
/// numbers are stable as long as the calendar is consistent.
@Suite
struct MonthlyStatsTests {

    /// `Calendar.current` in tests inherits the host timezone, so pin the
    /// calculator inputs to a known calendar to keep the assertions stable.
    private func cal() -> Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "Europe/Vienna")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 9) -> Date {
        var c = cal()
        c.timeZone = TimeZone(identifier: "Europe/Vienna")!
        return c.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    @Test func expectedHoursCountsMonToFriOnly() {
        // May 2025: 22 weekdays (5×4 weeks + Thu/Fri + Mon if we look at the
        // calendar) → expected = 22 × 8 = 176 with 8h/day. Cap `now` at end of
        // month so the full month is in scope.
        let now = date(2025, 5, 31, hour: 23)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025,
            month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [],
            absences: [],
            publicHolidays: [],
            now: now)
        // May 2025 has 22 weekdays (Mon-Fri only).
        #expect(s.expectedHours == 22 * 8.0)
        #expect(s.actualHours == 0)
    }

    @Test func publicHolidayReducesExpected() {
        let now = date(2025, 5, 31, hour: 23)
        let mayDay = PublicHoliday(
            id: 1,
            date: date(2025, 5, 1, hour: 0),
            name: "Tag der Arbeit",
            halfDay: false)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025,
            month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [],
            absences: [],
            publicHolidays: [mayDay],
            now: now)
        // 22 weekdays − 1 holiday = 21
        #expect(s.expectedHours == 21 * 8.0)
    }

    @Test func absenceReducesExpected() {
        let now = date(2025, 5, 31, hour: 23)
        let absence = Absence(
            id: 1,
            date: date(2025, 5, 15, hour: 0),
            duration: nil,
            type: "holiday",
            status: "approved",
            halfDay: false)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025,
            month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [],
            absences: [absence],
            publicHolidays: [],
            now: now)
        #expect(s.expectedHours == 21 * 8.0)
    }

    @Test func halfDayAbsenceCountsAsHalf() {
        let now = date(2025, 5, 31, hour: 23)
        let halfDay = Absence(
            id: 1,
            date: date(2025, 5, 15, hour: 0),
            duration: nil,
            type: "holiday",
            status: "approved",
            halfDay: true)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025,
            month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [],
            absences: [halfDay],
            publicHolidays: [],
            now: now)
        // 22 days − 0.5 = 21.5
        #expect(s.expectedHours == 21.5 * 8.0)
    }

    @Test func holidayAndAbsenceSameDayDontDoubleCount() {
        // Combined exempt is clamped to 1.0 — you can't deduct more than a full day.
        let now = date(2025, 5, 31, hour: 23)
        let h = PublicHoliday(id: 1, date: date(2025, 5, 1, hour: 0), name: "x", halfDay: false)
        let a = Absence(id: 2, date: date(2025, 5, 1, hour: 0), duration: nil,
                        type: "holiday", status: "approved", halfDay: false)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025, month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [], absences: [a], publicHolidays: [h],
            now: now)
        // 22 − 1 = 21 (not 20)
        #expect(s.expectedHours == 21 * 8.0)
    }

    @Test func currentMonthCappedAtStartOfTomorrow() {
        // "Now" is May 20 mid-morning. Expected should include May 20 fully
        // (today is counted) but stop before May 21.
        let now = date(2025, 5, 20, hour: 10)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025, month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [], absences: [], publicHolidays: [],
            now: now)
        // May 1-20: Mon-Fri days only. May 1=Thu, 2=Fri, (3-4 weekend), 5-9 (5), 12-16 (5), 19-20 (2) = 14 days.
        #expect(s.expectedHours == 14 * 8.0)
    }

    @Test func futureMonthInPastYearShowsFullMonth() {
        // Viewing July 2024 from May 2025: full 23-weekday month should be
        // counted (the cap is past nextMonthStart, so it clamps there).
        let now = date(2025, 5, 20)
        let s = MonthlyBalanceCalculator.stats(
            year: 2024, month: 7,
            hoursPerWorkingDay: 8.0,
            timesheets: [], absences: [], publicHolidays: [],
            now: now)
        // July 2024: 23 weekdays.
        #expect(s.expectedHours == 23 * 8.0)
    }

    @Test func timesheetActualHoursSumsDurations() {
        let now = date(2025, 5, 31, hour: 23)
        let t1 = TimesheetEntity(id: 1, project: 1, activity: 1,
                                  begin: date(2025, 5, 1, hour: 9),
                                  end: date(2025, 5, 1, hour: 12),
                                  description: nil)
        let t2 = TimesheetEntity(id: 2, project: 1, activity: 1,
                                  begin: date(2025, 5, 2, hour: 14),
                                  end: date(2025, 5, 2, hour: 18),
                                  description: nil)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025, month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [t1, t2], absences: [], publicHolidays: [],
            now: now)
        #expect(abs(s.actualHours - 7.0) < 0.001)
    }

    @Test func runningTimesheetClippedAtNow() {
        let now = date(2025, 5, 15, hour: 12)
        let running = TimesheetEntity(id: 1, project: 1, activity: 1,
                                       begin: date(2025, 5, 15, hour: 10),
                                       end: nil,
                                       description: nil)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025, month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [running], absences: [], publicHolidays: [],
            now: now)
        #expect(abs(s.actualHours - 2.0) < 0.001)
    }

    @Test func timesheetsOutsideMonthIgnored() {
        let now = date(2025, 5, 31, hour: 23)
        let prev = TimesheetEntity(id: 1, project: 1, activity: 1,
                                    begin: date(2025, 4, 30, hour: 9),
                                    end: date(2025, 4, 30, hour: 17),
                                    description: nil)
        let next = TimesheetEntity(id: 2, project: 1, activity: 1,
                                    begin: date(2025, 6, 1, hour: 9),
                                    end: date(2025, 6, 1, hour: 17),
                                    description: nil)
        let s = MonthlyBalanceCalculator.stats(
            year: 2025, month: 5,
            hoursPerWorkingDay: 8.0,
            timesheets: [prev, next], absences: [], publicHolidays: [],
            now: now)
        #expect(s.actualHours == 0)
    }

    // MARK: - months(for:)

    @Test func monthsForYearReturnsMonthsWithEntries() {
        let entries = [
            TimesheetEntity(id: 1, project: 1, activity: 1,
                             begin: date(2024, 3, 15, hour: 9),
                             end: date(2024, 3, 15, hour: 10),
                             description: nil),
            TimesheetEntity(id: 2, project: 1, activity: 1,
                             begin: date(2024, 7, 20, hour: 9),
                             end: date(2024, 7, 20, hour: 10),
                             description: nil),
            TimesheetEntity(id: 3, project: 1, activity: 1,
                             begin: date(2023, 12, 31, hour: 9),
                             end: date(2023, 12, 31, hour: 10),
                             description: nil),
        ]
        let months = MonthlyBalanceCalculator.months(
            for: 2024,
            timesheets: entries,
            now: date(2025, 5, 1))   // not the current year
        #expect(months == [3, 7])
    }

    @Test func monthsForCurrentYearAlwaysIncludesCurrentMonth() {
        let now = date(2025, 5, 20)
        let months = MonthlyBalanceCalculator.months(
            for: 2025,
            timesheets: [],
            now: now)
        #expect(months == [5])
    }
}
