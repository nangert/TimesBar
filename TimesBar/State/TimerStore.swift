import Foundation
import Combine
import SwiftUI

@MainActor
final class TimerStore: ObservableObject {
    @Published var active: TimesheetEntity?
    @Published var weekHours: [Double] = Array(repeating: 0, count: 7)
    @Published var elapsedString: String = "--:--:--"
    @Published var todayHours: Double = 0
    @Published var isAuthenticated: Bool = false
    @Published var recent: [TimesheetEntity] = []
    @Published var projectTitles: [Int: String] = [:]
    @Published var projectColors: [Int: String?] = [:]
    @Published var activityTitles: [Int: String] = [:]

    /// Per-day breakdown of hours by project for the current ISO week.
    /// Index 0 = Monday … 6 = Sunday. Each element is an array of
    /// (projectId, hours) pairs for that day, sorted descending by duration.
    @Published var weekProjectHours: [[(projectId: Int, hours: Double)]] = Array(repeating: [], count: 7)
    @Published var absences: [Absence] = []
    @Published var userMe: UserMe?

    /// Timesheets within ±1 day of a date the user is editing — used by the
    /// past-entry / edit-active forms to overlay existing entries on the
    /// TimeRangeBar so the user can see what's already logged. Cleared when
    /// the forms close.
    @Published var nearbyEntries: [TimesheetEntity] = []

    /// All tag names known to the connected Kimai instance. Populated on
    /// bootstrap and used as autocomplete suggestions in the start/edit forms.
    @Published var knownTags: [String] = []

    // MARK: - Sleep reconciliation

    /// Metadata captured at willSleep so we can detect an externally-stopped
    /// entry and reconstruct the reconciliation prompt at wake.
    struct SleepReconciliation: Equatable {
        let runningEntryId: Int
        let sleepStart: Date
        let wakeAt: Date
        let project: Int
        let activity: Int
        let description: String?
        let tags: [String]
    }

    @Published var pendingSleepReconciliation: SleepReconciliation?

    /// Snapshot stored at willSleep — nil if no timer was running.
    private var sleepSnapshot: (id: Int, sleepStart: Date, project: Int, activity: Int, description: String?, tags: [String])?

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

    func projectColor(for id: Int) -> Color {
        Color.forProject(id: id, hex: projectColors[id] ?? nil)
    }

    func activityTitle(for id: Int) -> String {
        activityTitles[id] ?? "Activity #\(id)"
    }

    // MARK: - Sleep reconciliation handlers

    /// Called when macOS sends willSleepNotification. Snapshots the running
    /// entry's metadata so we can validate it is still active at wake.
    func handleWillSleep(at now: Date = Date()) {
        guard let entry = active else {
            sleepSnapshot = nil
            return
        }
        sleepSnapshot = (id: entry.id,
                         sleepStart: now,
                         project: entry.project,
                         activity: entry.activity,
                         description: entry.description,
                         tags: entry.tags)
    }

    /// Called when macOS sends didWakeNotification. If sleep lasted ≥10 minutes
    /// and the same entry is still active, populates `pendingSleepReconciliation`.
    func handleDidWake(at now: Date = Date()) {
        guard
            let snap = sleepSnapshot,
            Self.shouldPrompt(sleepStart: snap.sleepStart, wakeAt: now),
            active?.id == snap.id
        else {
            // Clear snapshot so stale data doesn't affect the next cycle.
            sleepSnapshot = nil
            return
        }
        sleepSnapshot = nil
        pendingSleepReconciliation = SleepReconciliation(
            runningEntryId: snap.id,
            sleepStart: snap.sleepStart,
            wakeAt: now,
            project: snap.project,
            activity: snap.activity,
            description: snap.description,
            tags: snap.tags)
    }

    /// Returns true when the sleep duration meets the prompt threshold.
    nonisolated static func shouldPrompt(sleepStart: Date?,
                                         wakeAt: Date,
                                         threshold: TimeInterval = 600) -> Bool {
        guard let start = sleepStart else { return false }
        return wakeAt.timeIntervalSince(start) >= threshold
    }

    // MARK: - Sleep reconciliation actions

    /// Keep elapsed time as-is — simply dismiss the prompt.
    func keepRunning() {
        pendingSleepReconciliation = nil
    }

    /// Stop the running entry at the moment of sleep.
    func backdateStopToSleep() {
        guard let rec = pendingSleepReconciliation else { return }
        pendingSleepReconciliation = nil
        Task {
            await updateTimesheet(id: rec.runningEntryId, end: rec.sleepStart)
        }
    }

    /// Stop the running entry at sleep, then start a fresh one at wake with
    /// the same project / activity / description / tags.
    func splitAtSleep() {
        guard let rec = pendingSleepReconciliation else { return }
        pendingSleepReconciliation = nil
        Task {
            _ = await updateTimesheet(id: rec.runningEntryId, end: rec.sleepStart)
            _ = await logEntry(
                project: rec.project,
                activity: rec.activity,
                begin: rec.wakeAt,
                end: nil,
                description: rec.description,
                tags: rec.tags.isEmpty ? nil : rec.tags)
        }
    }

    // MARK: - Pure helpers (unit-tested)

    /// Returns the 0-based weekday index (Monday=0 … Sunday=6) for `now`
    /// within the ISO week that starts on `weekStart`.
    nonisolated static func todayIndex(weekStart: Date, now: Date, calendar: Calendar) -> Int {
        max(0, min(6, calendar.dateComponents([.day], from: weekStart, to: now).day ?? 0))
    }

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

    /// Per-day breakdown of hours by project for the current ISO week.
    /// Returns an array of 7 elements (Monday=0 … Sunday=6); each element is a
    /// list of `(projectId, hours)` pairs sorted descending by hours.
    nonisolated static func weekProjectHours(entries: [TimesheetEntity],
                                             weekStart: Date,
                                             calendar: Calendar,
                                             now: Date = Date()) -> [[(projectId: Int, hours: Double)]] {
        var buckets: [[Int: Double]] = Array(repeating: [:], count: 7)
        for entry in entries {
            let stop = entry.end ?? now
            let elapsed = stop.timeIntervalSince(entry.begin)
            guard elapsed > 0 else { continue }
            let day = calendar.dateComponents([.day], from: weekStart, to: entry.begin).day ?? 0
            guard day >= 0, day < 7 else { continue }
            buckets[day][entry.project, default: 0] += elapsed / 3600.0
        }
        return buckets.map { dict in
            dict.map { (projectId: $0.key, hours: $0.value) }
                .sorted { $0.hours > $1.hours }
        }
    }

    // MARK: - Live state

    private var pollTimer: Timer?
    private var tickTimer: Timer?
    private var client: KimaiClient?
    /// Timestamp of the last `refreshWeek()` call — used by `tickElapsed` to
    /// compute the live delta for the currently running timer without polling.
    private var weekHoursRefreshedAt: Date = .distantPast

    /// Rebuild the client after the base URL changes. Reads the current token
    /// from the Keychain and constructs a fresh `KimaiClient` with the new URL,
    /// then refreshes to verify the new endpoint is reachable.
    func rebuildClient() async {
        guard let token = TokenStore().read() else { return }
        client = KimaiClient(baseURL: UserPreferences.shared.baseURL, token: token)
        await refresh()
    }

    func bootstrap() {
        if let token = TokenStore().read() {
            client = KimaiClient(baseURL: UserPreferences.shared.baseURL, token: token)
            isAuthenticated = true
            Task {
                await loadUserMe()
                await refreshDirectory()
                await refreshTags()
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
        userMe = await tryAuth { try await client.me() }
    }

    func detectFirstTimesheetYear() async {
        guard let client else { return }
        if let year = await tryAuth({ try await client.firstTimesheetYear() }),
           let y = year, y > 1970 {
            detectedFirstTimesheetYear = y
        }
    }

    /// Run a client call, returning nil on any error. If Kimai answered 401/403
    /// we tear down the in-memory auth state so the menu bar flips back to the
    /// token form — the canonical cause is a revoked or expired API token.
    private func tryAuth<T>(_ block: () async throws -> T) async -> T? {
        do {
            return try await block()
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return nil
        } catch {
            return nil
        }
    }

    /// Tear down live state when Kimai stops accepting the token. Mirrors
    /// `signOut()` but keeps the Keychain entry — the user may want to paste
    /// a fresh token and continue, and we don't know if the old one is just
    /// temporarily revoked vs. permanently gone.
    private func handleUnauthorized() {
        guard isAuthenticated else { return }
        NSLog("TimesBar: Kimai rejected the token (401/403); returning to sign-in")
        pollTimer?.invalidate()
        tickTimer?.invalidate()
        client = nil
        active = nil
        weekHours = Array(repeating: 0, count: 7)
        weekProjectHours = Array(repeating: [], count: 7)
        elapsedString = "--:--:--"
        recent = []
        loadingYear = nil
        isAuthenticated = false
    }

    func authenticate(with token: String) async -> Bool {
        let candidate = KimaiClient(baseURL: UserPreferences.shared.baseURL, token: token)
        do {
            try await candidate.ping()
        } catch {
            return false
        }
        guard TokenStore().save(token) else {
            // Token was valid but Keychain rejected the write — don't claim
            // authenticated, the next launch wouldn't find the token anyway.
            return false
        }
        client = candidate
        isAuthenticated = true
        await loadUserMe()
        await refreshDirectory()
        await refreshTags()
        await detectFirstTimesheetYear()
        await refresh()
        startTimers()
        return true
    }

    func refreshTags() async {
        guard let client else { return }
        if let fetched = await tryAuth({ try await client.tags() }) {
            knownTags = fetched.sorted()
        }
    }

    func refreshDirectory() async {
        guard let client else { return }
        if let p = await tryAuth({ try await client.projects() }) {
            projectTitles = Dictionary(uniqueKeysWithValues: p.map { ($0.id, $0.displayTitle) })
            projectColors = Dictionary(uniqueKeysWithValues: p.map { ($0.id, $0.color) })
        }
        if let a = await tryAuth({ try await client.activities() }) {
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

        async let timesheets = client.timesheets(begin: begin, end: end)
        async let absences = client.absences(begin: begin, end: end, status: "approved")
        async let holidays = client.publicHolidays(begin: begin, end: end, group: publicHolidayGroupId)

        do {
            let (t, a, h) = try await (timesheets, absences, holidays)
            yearlyData = YearlyData(year: year, timesheets: t, absences: a, publicHolidays: h)
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            yearlyData = nil
        } catch {
            yearlyData = nil
        }
        loadingYear = nil
    }

    /// Create an absence request (vacation, sick day, etc.) for the current
    /// user. Returns `true` on success; refreshes the cached absence list so
    /// the Time-off panel updates immediately.
    @discardableResult
    func requestAbsence(date: Date,
                        end: Date?,
                        type: String,
                        halfDay: Bool,
                        comment: String?) async -> Bool {
        guard let client, let userId = userMe?.id else { return false }
        do {
            _ = try await client.createAbsence(
                user: userId,
                date: date,
                end: end,
                type: type,
                halfDay: halfDay,
                comment: comment)
            await refreshAbsences()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
    }

    /// Cancel an absence by ID. Refreshes the absence list on success so the
    /// row disappears from the Upcoming list without a manual reload.
    @discardableResult
    func cancelAbsence(id: Int) async -> Bool {
        guard let client else { return false }
        do {
            try await client.deleteAbsence(id: id)
            await refreshAbsences()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
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
        if let entries = await tryAuth({ try await client.absences(begin: begin, end: end, status: "approved") }) {
            absences = entries
        }
    }

    func signOut() {
        TokenStore().delete()
        client = nil
        active = nil
        weekHours = Array(repeating: 0, count: 7)
        weekProjectHours = Array(repeating: [], count: 7)
        elapsedString = "--:--:--"
        isAuthenticated = false
        recent = []
        projectTitles = [:]
        projectColors = [:]
        activityTitles = [:]
        absences = []
        knownTags = []
        yearlyData = nil
        loadingYear = nil
        detectedFirstTimesheetYear = nil
        userMe = nil
        pollTimer?.invalidate()
        tickTimer?.invalidate()
    }

    func stop() async {
        guard let client, let id = active?.id else { return }
        _ = await tryAuth { try await client.stop(id: id) }
        await refresh()
    }

    func refresh() async {
        guard let client else { return }
        active = (await tryAuth { try await client.active() })?.first
        await refreshWeek()
        await refreshRecent()
        tickElapsed()
    }

    /// Fetch timesheets covering the given day ±1 day. Populates
    /// `nearbyEntries` so the TimeRangeBar can visualize what's already
    /// logged in the window. ±1 day covers midnight-crossing 12h strips.
    func refreshNearbyEntries(around day: Date) async {
        guard let client else { return }
        var cal = Calendar.current
        cal.timeZone = .current
        let startOfDay = cal.startOfDay(for: day)
        guard let begin = cal.date(byAdding: .day, value: -1, to: startOfDay),
              let end = cal.date(byAdding: .day, value: 2, to: startOfDay) else { return }
        if let entries = await tryAuth({ try await client.timesheets(begin: begin, end: end) }) {
            nearbyEntries = entries
        }
    }

    func clearNearbyEntries() {
        nearbyEntries = []
    }

    func refreshRecent() async {
        guard let client else { return }
        if let entries = await tryAuth({ try await client.recent() }) {
            recent = Array(entries.prefix(5))
        }
    }

    func start(project: Int, activity: Int, description: String?, tags: [String]? = nil) async {
        _ = await startCheckingResult(project: project, activity: activity, description: description, tags: tags)
    }

    @discardableResult
    func startCheckingResult(project: Int, activity: Int, description: String?, tags: [String]? = nil) async -> Bool {
        guard let client else { return false }
        do {
            _ = try await client.start(project: project, activity: activity, description: description, tags: tags)
            await refresh()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
    }

    /// Log a timesheet entry with an explicit begin. If `end` is nil the entry
    /// is created in the running state — used by the "log past entry" toggle
    /// in StartTimerForm to backdate a freshly started timer. Kimai rejects a
    /// second concurrent active entry, so this path mirrors the existing
    /// invariant: only one running timer at a time.
    @discardableResult
    func logEntry(project: Int,
                  activity: Int,
                  begin: Date,
                  end: Date?,
                  description: String?,
                  tags: [String]? = nil) async -> Bool {
        guard let client else { return false }
        do {
            _ = try await client.createTimesheet(
                begin: begin,
                end: end,
                project: project,
                activity: activity,
                description: description,
                tags: tags)
            await refresh()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
    }

    /// PATCH any completed timesheet by ID. Used by `EditTimesheetForm`. Any nil
    /// argument is left unchanged on the server.
    @discardableResult
    func updateTimesheet(id: Int,
                         project: Int? = nil,
                         activity: Int? = nil,
                         begin: Date? = nil,
                         end: Date? = nil,
                         description: String? = nil,
                         tags: [String]? = nil) async -> Bool {
        guard let client else { return false }
        do {
            _ = try await client.updateTimesheet(
                id: id,
                project: project,
                activity: activity,
                begin: begin,
                end: end,
                description: description,
                tags: tags)
            await refresh()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
    }

    /// DELETE a timesheet entry by ID. Refreshes recent + week after success.
    @discardableResult
    func deleteTimesheet(id: Int) async -> Bool {
        guard let client else { return false }
        do {
            try await client.deleteTimesheet(id: id)
            await refresh()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
    }

    /// Duplicate a timesheet entry via Kimai's POST /duplicate endpoint.
    /// Refreshes after success so the new entry appears in the recent list.
    @discardableResult
    func duplicateTimesheet(id: Int) async -> Bool {
        guard let client else { return false }
        do {
            _ = try await client.duplicateTimesheet(id: id)
            await refresh()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
    }

    /// PATCH the currently running timer. Any nil argument is left unchanged.
    /// Returns false if there is no active timer or Kimai rejects the edit
    /// (e.g. the activity does not belong to the new project).
    @discardableResult
    func updateActiveTimer(begin: Date? = nil,
                           project: Int? = nil,
                           activity: Int? = nil,
                           description: String? = nil,
                           tags: [String]? = nil) async -> Bool {
        guard let client, let id = active?.id else { return false }
        do {
            _ = try await client.updateTimesheet(
                id: id,
                project: project,
                activity: activity,
                begin: begin,
                description: description,
                tags: tags)
            await refresh()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
        } catch {
            return false
        }
    }

    /// Resume a previous timesheet entry via Kimai's dedicated restart endpoint.
    /// Unlike `startCheckingResult`, which re-creates the entry from scratch via
    /// `POST /api/timesheets`, this copies the original's tags and description
    /// for free — the quick-start UI hits this path so re-running yesterday's
    /// `#deep-work · Auth refactor` entry preserves both.
    @discardableResult
    func resumeCheckingResult(timesheetId: Int) async -> Bool {
        guard let client else { return false }
        do {
            _ = try await client.restart(id: timesheetId, copyAll: true)
            await refresh()
            return true
        } catch KimaiError.unauthorized {
            handleUnauthorized()
            return false
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
        if let entries = await tryAuth({ try await client.timesheets(begin: weekStart, end: weekEnd) }) {
            weekHours = Self.weekHours(entries: entries, weekStart: weekStart, calendar: cal, now: now)
            weekProjectHours = Self.weekProjectHours(entries: entries, weekStart: weekStart, calendar: cal, now: now)
            weekHoursRefreshedAt = now
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
        let now = Date()
        guard let begin = active?.begin else {
            elapsedString = "--:--:--"
            todayHours = Self.todayHoursValue(
                weekHours: weekHours, activeBegin: nil,
                weekHoursRefreshedAt: weekHoursRefreshedAt, now: now)
            return
        }
        elapsedString = Self.elapsedString(seconds: Int(now.timeIntervalSince(begin)))
        todayHours = Self.todayHoursValue(
            weekHours: weekHours, activeBegin: begin,
            weekHoursRefreshedAt: weekHoursRefreshedAt, now: now)
    }

    /// Computes live today-hours from the last-fetched `weekHours` bucket.
    /// `weekHours[todayIdx]` was computed at `weekHoursRefreshedAt` using
    /// `entry.end ?? refreshTime` for any running entry, so it already includes
    /// elapsed up to that moment. We add the delta `(now − refreshedAt)` for
    /// a timer that started today so the value ticks every second between polls.
    nonisolated static func todayHoursValue(weekHours: [Double],
                                            activeBegin: Date?,
                                            weekHoursRefreshedAt: Date,
                                            now: Date,
                                            calendar: Calendar? = nil) -> Double {
        let cal = calendar ?? {
            var c = Calendar(identifier: .iso8601)
            c.timeZone = .current
            return c
        }()
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let weekStart = cal.date(from: comps) else { return 0 }
        let idx = todayIndex(weekStart: weekStart, now: now, calendar: cal)
        let stored = weekHours[safe: idx] ?? 0

        guard let begin = activeBegin else { return stored }
        let startOfDay = cal.startOfDay(for: now)
        // Only add the live delta when the active timer started today.
        guard begin >= startOfDay else { return stored }
        let deltaSecs = max(0, now.timeIntervalSince(max(begin, weekHoursRefreshedAt)))
        return stored + deltaSecs / 3600.0
    }
}
