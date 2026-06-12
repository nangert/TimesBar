import Foundation

// MARK: - Vacation accounting
//
// Pure derivations over `absences`, `userMe`, and `detectedFirstTimesheetYear`
// — no networking, no timers. Kept in an extension so TimerStore.swift stays
// focused on live timer state.
extension TimerStore {

    /// Annual vacation budget — sourced from `/api/users/me` → preference
    /// `holidays`. Falls back to 25 if not loaded yet.
    var vacationBudgetDays: Int { userMe?.holidaysPerYear ?? 25 }

    /// Contract start date from /api/users/me. Drives the per-year accrual
    /// math; the first year is prorated by months remaining.
    var contractStartDate: Date? { userMe?.workStartDate }

    /// One year's vacation summary, supporting half-day weights.
    struct VacationYearStats: Equatable {
        let year: Int
        let available: Double
        let used: Double
        var remaining: Double { max(available - used, 0) }
    }

    /// First year we count toward the running balance. Prefers the contract
    /// start year from /api/users/me; falls back to the earliest timesheet
    /// year if the contract preference is missing.
    var vacationTrackingStartYear: Int {
        if let date = contractStartDate {
            return Calendar.current.component(.year, from: date)
        }
        return detectedFirstTimesheetYear ?? Calendar.current.component(.year, from: Date())
    }

    /// Years to display in the breakdown — from the contract start year (or
    /// detected first-timesheet year as fallback) through the current year.
    var vacationYears: [Int] {
        let nowYear = Calendar.current.component(.year, from: Date())
        let start = min(vacationTrackingStartYear, nowYear)
        return Array(start...nowYear)
    }

    /// Per-year stats: prorated `available` budget + `used` approved
    /// holidays (half-day-weighted) for the given calendar year.
    func vacationStats(for year: Int) -> VacationYearStats {
        let cal = Calendar.current
        let annual = Double(vacationBudgetDays)
        var available: Double = annual

        if let start = contractStartDate {
            let startYear = cal.component(.year, from: start)
            if year < startYear {
                available = 0
            } else if year == startYear {
                // Prorate by months remaining (inclusive of the start month).
                // July (month=7) → 13 − 7 = 6 → 6/12 × 25 = 12.5.
                let startMonth = cal.component(.month, from: start)
                let monthsRemaining = Double(max(13 - startMonth, 0))
                available = annual * monthsRemaining / 12.0
            }
        }

        let used = absences
            .filter { $0.type.lowercased() == "holiday"
                && cal.component(.year, from: $0.date) == year }
            .reduce(0.0) { $0 + $1.dayWeight }

        return VacationYearStats(year: year, available: available, used: used)
    }

    /// Stats for every tracked year, ascending.
    var vacationBreakdown: [VacationYearStats] {
        vacationYears.map { vacationStats(for: $0) }
    }

    /// Total available across every tracked year (prorated first year).
    var vacationTotalAvailable: Double {
        vacationBreakdown.reduce(0.0) { $0 + $1.available }
    }

    /// Total approved holiday days used across every tracked year.
    var vacationUsedDays: Double {
        vacationBreakdown.reduce(0.0) { $0 + $1.used }
    }

    var vacationRemainingDays: Double {
        max(vacationTotalAvailable - vacationUsedDays, 0)
    }

    /// Upcoming approved absences from today forward, sorted ascending.
    var upcomingAbsences: [Absence] {
        let today = Calendar.current.startOfDay(for: Date())
        return absences
            .filter { $0.date >= today }
            .sorted { $0.date < $1.date }
    }
}
