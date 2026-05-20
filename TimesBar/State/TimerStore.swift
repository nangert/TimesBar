import Foundation
import Combine

@MainActor
final class TimerStore: ObservableObject {
    @Published var active: TimesheetEntity?
    @Published var weekHours: [Double] = Array(repeating: 0, count: 7)
    @Published var elapsedString: String = "--:--:--"
    @Published var isAuthenticated: Bool = false
    @Published var recent: [TimesheetEntity] = []
    @Published var projectTitles: [Int: String] = [:]
    @Published var activityTitles: [Int: String] = [:]
    @Published var absences: [Absence] = []
    @Published var userMe: UserMe?

    // Monthly-balance cache: full set of raw data per year, keyed by year.
    struct YearlyData: Equatable {
        let year: Int
        let timesheets: [TimesheetEntity]
        let absences: [Absence]
        let publicHolidays: [PublicHoliday]
    }
    @Published var yearlyData: YearlyData?
    @Published var loadingYear: Int?

    /// Contractual working hours per week. Sourced from `/api/users/me` →
    /// preference `hours_per_week` (stored in Kimai as seconds). Falls back
    /// to 40 if the preference hasn't loaded yet.
    var hoursPerWeek: Double { userMe?.hoursPerWeek ?? 40.0 }

    var hoursPerWorkingDay: Double { hoursPerWeek / 5.0 }

    /// Public-holiday group ID assigned to the user — drives which holidays
    /// `/api/public-holidays` returns. Without this, Kimai returns its default
    /// group which is usually empty.
    var publicHolidayGroupId: Int? { userMe?.publicHolidayGroupId }

    /// Auto-detected year of the user's earliest timesheet. Populated by
    /// `detectFirstTimesheetYear()` on bootstrap. Drives `vacationTrackingStartYear`.
    @Published var detectedFirstTimesheetYear: Int?

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

    /// Number of calendar years between the tracking start and today.
    var vacationYearsAccrued: Int { max(vacationYears.count, 1) }

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

    var isRunning: Bool { active != nil }

    func projectTitle(for id: Int) -> String {
        projectTitles[id] ?? "Project #\(id)"
    }

    func activityTitle(for id: Int) -> String {
        activityTitles[id] ?? "Activity #\(id)"
    }

    // MARK: - Pure helpers (unit-tested)

    nonisolated static func elapsedString(seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    nonisolated static func weekHours(entries: [TimesheetEntity],
                                      weekStart: Date,
                                      calendar: Calendar,
                                      now: Date = Date()) -> [Double] {
        var buckets = Array(repeating: 0.0, count: 7)
        for entry in entries {
            let stop = entry.end ?? now
            let elapsed = stop.timeIntervalSince(entry.begin)
            guard elapsed > 0 else { continue }
            let day = calendar.dateComponents([.day], from: weekStart, to: entry.begin).day ?? 0
            guard day >= 0, day < 7 else { continue }
            buckets[day] += elapsed / 3600.0
        }
        return buckets
    }

    // MARK: - Live state

    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var client: KimaiClient?

    func bootstrap() {
        if let token = TokenStore().read() {
            client = KimaiClient(token: token)
            isAuthenticated = true
            Task {
                await loadUserMe()
                await refreshDirectory()
                await detectFirstTimesheetYear()
                await refreshAbsences()
                await refresh()
            }
            startTimers()
        } else {
            isAuthenticated = false
        }
    }

    func loadUserMe() async {
        guard let client else { return }
        userMe = try? await client.me()
    }

    func detectFirstTimesheetYear() async {
        guard let client else { return }
        if let year = try? await client.firstTimesheetYear(), year > 1970 {
            detectedFirstTimesheetYear = year
        }
    }

    func authenticate(with token: String) async -> Bool {
        let candidate = KimaiClient(token: token)
        do {
            try await candidate.ping()
        } catch {
            return false
        }
        TokenStore().save(token)
        client = candidate
        isAuthenticated = true
        await loadUserMe()
        await refreshDirectory()
        await detectFirstTimesheetYear()
        await refresh()
        startTimers()
        return true
    }

    func refreshDirectory() async {
        guard let client else { return }
        async let projects = client.projects()
        async let activities = client.activities()
        if let p = try? await projects {
            projectTitles = Dictionary(uniqueKeysWithValues: p.map { ($0.id, $0.displayTitle) })
        }
        if let a = try? await activities {
            activityTitles = Dictionary(uniqueKeysWithValues: a.map { ($0.id, $0.name) })
        }
    }

    /// Load all raw data needed for the Monthly balance page for one year.
    /// Three concurrent calls (timesheets, absences, public holidays).
    func loadYearlyData(_ year: Int) async {
        guard let client else { return }
        loadingYear = year
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        guard let begin = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { loadingYear = nil; return }

        async let timesheets = client.timesheets(begin: begin, end: end, size: 500)
        async let absences = client.absences(begin: begin, end: end, status: "approved")
        async let holidays = client.publicHolidays(begin: begin, end: end, group: publicHolidayGroupId)

        let t = (try? await timesheets) ?? []
        let a = (try? await absences) ?? []
        let h = (try? await holidays) ?? []

        yearlyData = YearlyData(year: year, timesheets: t, absences: a, publicHolidays: h)
        loadingYear = nil
    }

    /// Fetch approved absences from the tracking start year through the end
    /// of the current year. Rarely changes, so we call it on bootstrap, on
    /// entering the Time-off panel, and when the budget/year settings change.
    func refreshAbsences() async {
        guard let client else { return }
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let currentYear = cal.component(.year, from: Date())
        guard let begin = cal.date(from: DateComponents(year: vacationTrackingStartYear, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: currentYear + 1, month: 1, day: 1))
        else { return }
        if let entries = try? await client.absences(begin: begin, end: end, status: "approved") {
            absences = entries
        }
    }

    func signOut() {
        TokenStore().delete()
        client = nil
        active = nil
        weekHours = Array(repeating: 0, count: 7)
        elapsedString = "--:--:--"
        isAuthenticated = false
        recent = []
        projectTitles = [:]
        activityTitles = [:]
        absences = []
        yearlyData = nil
        detectedFirstTimesheetYear = nil
        userMe = nil
        pollTimer?.invalidate()
        tickTimer?.invalidate()
    }

    func stop() async {
        guard let client, let id = active?.id else { return }
        _ = try? await client.stop(id: id)
        await refresh()
    }

    func refresh() async {
        guard let client else { return }
        active = (try? await client.active())?.first
        await refreshWeek()
        await refreshRecent()
        tickElapsed()
    }

    func refreshRecent() async {
        guard let client else { return }
        if let entries = try? await client.recent() {
            recent = Array(entries.prefix(5))
        }
    }

    func start(project: Int, activity: Int, description: String?) async {
        _ = await startCheckingResult(project: project, activity: activity, description: description)
    }

    @discardableResult
    func startCheckingResult(project: Int, activity: Int, description: String?) async -> Bool {
        guard let client else { return false }
        do {
            _ = try await client.start(project: project, activity: activity, description: description)
            await refresh()
            return true
        } catch {
            return false
        }
    }

    private func refreshWeek() async {
        guard let client else { return }
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let now = Date()
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = cal.date(from: comps) else { return }
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        if let entries = try? await client.timesheets(begin: weekStart, end: weekEnd) {
            weekHours = Self.weekHours(entries: entries, weekStart: weekStart, calendar: cal, now: now)
        }
    }

    private func startTimers() {
        pollTimer?.invalidate()
        tickTimer?.invalidate()

        // Schedule on `.common` so the timers continue to fire while the MenuBarExtra
        // dropdown is open (the run loop is in `.eventTracking` then, and a timer
        // scheduled in `.default` would silently freeze).
        let poll = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        let tick = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickElapsed() }
        }
        RunLoop.main.add(poll, forMode: .common)
        RunLoop.main.add(tick, forMode: .common)
        pollTimer = poll
        tickTimer = tick
    }

    private func tickElapsed() {
        guard let begin = active?.begin else { elapsedString = "--:--:--"; return }
        elapsedString = Self.elapsedString(seconds: Int(Date().timeIntervalSince(begin)))
    }
}
