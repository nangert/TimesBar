import Testing
import Foundation
@testable import TimesBar

/// Tests for `TimerStore.vacationStats(for:year:)` and the per-year
/// breakdown / proration math. These mirror the Kimai dashboard numbers
/// for a user whose contract started mid-year.
@MainActor
@Suite
struct VacationStatsTests {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// Build a minimal `UserMe` carrying just the preferences `TimerStore`
    /// reads. We round-trip through JSON because `UserMe`'s init is the
    /// `Decodable` synthesized one.
    private func makeUserMe(holidays: Int, workStart: String? = nil) -> UserMe {
        var prefs: [[String: String]] = [
            ["name": "holidays", "value": String(holidays)],
            ["name": "hours_per_week", "value": "138600"],   // 38.5h
        ]
        if let workStart {
            prefs.append(["name": "work_start_day", "value": workStart])
        }
        let payload: [String: Any] = [
            "id": 1,
            "alias": "Tester",
            "preferences": prefs,
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        return try! JSONDecoder.kimai.decode(UserMe.self, from: data)
    }

    private func makeAbsence(_ d: Date, halfDay: Bool = false, type: String = "holiday") -> Absence {
        Absence(id: Int.random(in: 1...10_000),
                date: d,
                duration: nil,
                type: type,
                status: "approved",
                halfDay: halfDay)
    }

    @Test func contractStartedInJulyProratesFirstYear() {
        // July → 6/12 × 25 = 12.5
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-07-01")
        let s = store.vacationStats(for: 2024)
        #expect(s.available == 12.5)
        #expect(s.used == 0)
    }

    @Test func contractStartedInJanuaryGivesFullYear() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-01-01")
        let s = store.vacationStats(for: 2024)
        #expect(s.available == 25)
    }

    @Test func yearsBeforeContractStartHaveZeroBudget() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-07-01")
        let s = store.vacationStats(for: 2023)
        #expect(s.available == 0)
    }

    @Test func yearAfterContractStartGetsFullBudget() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-07-01")
        #expect(store.vacationStats(for: 2025).available == 25)
        #expect(store.vacationStats(for: 2026).available == 25)
    }

    @Test func usedSumsApprovedHolidayAbsencesForTheYear() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-07-01")
        store.absences = [
            makeAbsence(date(2024, 8, 5)),
            makeAbsence(date(2024, 8, 6)),
            makeAbsence(date(2024, 12, 27)),
            makeAbsence(date(2025, 1, 2)),    // different year, excluded
        ]
        #expect(store.vacationStats(for: 2024).used == 3)
        #expect(store.vacationStats(for: 2025).used == 1)
    }

    @Test func halfDayCountsAsHalf() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-07-01")
        store.absences = [
            makeAbsence(date(2024, 8, 5), halfDay: true),
            makeAbsence(date(2024, 8, 6)),
        ]
        #expect(store.vacationStats(for: 2024).used == 1.5)
    }

    @Test func sickAbsencesDontCountAsVacation() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-01-01")
        store.absences = [
            makeAbsence(date(2024, 8, 5), type: "sick"),
            makeAbsence(date(2024, 8, 6), type: "freecompensation"),
            makeAbsence(date(2024, 8, 7), type: "holiday"),
        ]
        #expect(store.vacationStats(for: 2024).used == 1)
    }

    @Test func remainingClampedToZero() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-01-01")
        store.absences = (1...30).map { i in
            makeAbsence(date(2024, 1, min(i, 28)))
        }
        // Used > available → remaining = 0, not negative.
        let s = store.vacationStats(for: 2024)
        #expect(s.used >= s.available)
        #expect(s.remaining == 0)
    }

    @Test func breakdownMatchesDashboardExample() {
        // The user's actual Kimai numbers: contract 2024-07-01, 25 days/year.
        // 2024: 3.5 / 12.5, 2025: 12 / 25, 2026: 0 / 25
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-07-01")
        store.absences = (1...3).map { makeAbsence(date(2024, 8, $0)) }
            + [makeAbsence(date(2024, 8, 4), halfDay: true)]   // → 3.5 in 2024
            + (1...12).map { makeAbsence(date(2025, 2, $0)) }  // → 12 in 2025
        // We can't time-travel to 2026 for breakdown, but vacationStats
        // works year-by-year regardless of "now".
        #expect(store.vacationStats(for: 2024).used == 3.5)
        #expect(store.vacationStats(for: 2024).available == 12.5)
        #expect(store.vacationStats(for: 2025).used == 12)
        #expect(store.vacationStats(for: 2025).available == 25)
        #expect(store.vacationStats(for: 2026).used == 0)
        #expect(store.vacationStats(for: 2026).available == 25)
    }

    @Test func detectedFirstTimesheetYearDrivesTrackingStartWithoutContract() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25)   // no workStart
        store.detectedFirstTimesheetYear = 2023
        #expect(store.vacationTrackingStartYear == 2023)
    }

    @Test func contractStartTakesPrecedenceOverDetectedYear() {
        let store = TimerStore()
        store.userMe = makeUserMe(holidays: 25, workStart: "2024-07-01")
        store.detectedFirstTimesheetYear = 2023
        #expect(store.vacationTrackingStartYear == 2024)
    }
}
