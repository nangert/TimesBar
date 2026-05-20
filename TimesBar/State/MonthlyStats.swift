import Foundation

struct MonthlyStats: Equatable {
    let month: Int        // 1...12
    let expectedHours: Double
    let actualHours: Double

    var balanceHours: Double { actualHours - expectedHours }
    var hasData: Bool { expectedHours > 0 || actualHours > 0 }
}

enum MonthlyBalanceCalculator {
    /// Compute one month of stats from the cached raw collections.
    /// `hoursPerWorkingDay` is supplied by the caller — typically
    /// `TimerStore.hoursPerWorkingDay` (= `hoursPerWeek / 5`).
    static func stats(year: Int,
                      month: Int,
                      hoursPerWorkingDay: Double,
                      timesheets: [TimesheetEntity],
                      absences: [Absence],
                      publicHolidays: [PublicHoliday],
                      now: Date = Date()) -> MonthlyStats {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        guard let monthStart = cal.date(from: DateComponents(year: year, month: month, day: 1)),
              let nextMonthStart = cal.date(byAdding: .month, value: 1, to: monthStart)
        else {
            return MonthlyStats(month: month, expectedHours: 0, actualHours: 0)
        }

        // Cap at the start of tomorrow — i.e. today *is* counted as a
        // working day. The expected number is cumulative "through today".
        let endOfWindow = min(nextMonthStart,
                              max(monthStart, cal.startOfDay(for: now).addingTimeInterval(86_400)))

        // Build half-day-aware weight maps by start-of-day key
        var holidayWeights: [Date: Double] = [:]
        for h in publicHolidays where h.date >= monthStart && h.date < nextMonthStart {
            holidayWeights[cal.startOfDay(for: h.date), default: 0] += h.dayWeight
        }
        var absenceWeights: [Date: Double] = [:]
        for a in absences where a.date >= monthStart && a.date < nextMonthStart {
            absenceWeights[cal.startOfDay(for: a.date), default: 0] += a.dayWeight
        }

        var expectedDays = 0.0
        var day = monthStart
        while day < endOfWindow {
            let weekday = cal.component(.weekday, from: day) // Sunday=1 ... Saturday=7
            let isMonToFri = weekday >= 2 && weekday <= 6
            if isMonToFri {
                let key = cal.startOfDay(for: day)
                let exempt = (holidayWeights[key] ?? 0) + (absenceWeights[key] ?? 0)
                expectedDays += max(1.0 - min(exempt, 1.0), 0)
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        let expectedHours = expectedDays * hoursPerWorkingDay

        // Sum timesheet durations that started inside this month, clipped at "now"
        var totalSeconds: TimeInterval = 0
        for t in timesheets where t.begin >= monthStart && t.begin < nextMonthStart {
            let stop = min(t.end ?? now, now)
            let delta = stop.timeIntervalSince(t.begin)
            if delta > 0 { totalSeconds += delta }
        }
        let actualHours = totalSeconds / 3600.0

        return MonthlyStats(month: month, expectedHours: expectedHours, actualHours: actualHours)
    }

    /// All months from January through (current month, or December for past years).
    static func months(for year: Int, now: Date = Date()) -> [Int] {
        let cal = Calendar(identifier: .iso8601)
        let nowYear = cal.component(.year, from: now)
        if year < nowYear { return Array(1...12) }
        if year > nowYear { return [] }
        let lastMonth = cal.component(.month, from: now)
        return Array(1...lastMonth)
    }
}
