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

    // Monthly-balance cache: full set of raw data per year, keyed by year.
    struct YearlyData: Equatable {
        let year: Int
        let timesheets: [TimesheetEntity]
        let absences: [Absence]
        let publicHolidays: [PublicHoliday]
    }
    @Published var yearlyData: YearlyData?
    @Published var loadingYear: Int?

    private static let vacationBudgetDaysKey = "vacationBudgetDays"

    /// Auto-detected year of the user's earliest timesheet. Populated by
    /// `detectFirstTimesheetYear()` on bootstrap. Drives `vacationTrackingStartYear`.
    @Published var detectedFirstTimesheetYear: Int?

    /// Annual vacation budget. The Kimai API doesn't expose the
    /// `holidaysPerYear` contract field on this install, so the user
    /// configures it once via the Time-off page.
    var vacationBudgetDays: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: Self.vacationBudgetDaysKey)
            return stored > 0 ? stored : 25
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Self.vacationBudgetDaysKey)
            Task { await refreshAbsences() }
        }
    }

    /// First year we count toward the running balance. Auto-detected from
    /// the earliest timesheet; falls back to the current year if nothing's
    /// logged yet.
    var vacationTrackingStartYear: Int {
        detectedFirstTimesheetYear ?? Calendar.current.component(.year, from: Date())
    }

    /// Number of calendar years between the tracking start and today,
    /// inclusive — i.e. how many annual allotments have accrued.
    var vacationYearsAccrued: Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return max(currentYear - vacationTrackingStartYear + 1, 1)
    }

    /// Total vacation days accrued since the tracking start year.
    var vacationTotalAvailable: Int {
        vacationBudgetDays * vacationYearsAccrued
    }

    var vacationRemainingDays: Double {
        max(Double(vacationTotalAvailable) - vacationUsedDays, 0)
    }

    /// Approved vacation days used in the current calendar year.
    var vacationUsedDays: Double {
        absences
            .filter { $0.type.lowercased() == "holiday" }
            .reduce(0.0) { $0 + $1.dayWeight }
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
        async let holidays = client.publicHolidays(begin: begin, end: end)

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
