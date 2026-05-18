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
                await refresh()
            }
            startTimers()
        } else {
            isAuthenticated = false
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
        guard let client else { return }
        _ = try? await client.start(project: project, activity: activity, description: description)
        await refresh()
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickElapsed() }
        }
    }

    private func tickElapsed() {
        guard let begin = active?.begin else { elapsedString = "--:--:--"; return }
        elapsedString = Self.elapsedString(seconds: Int(Date().timeIntervalSince(begin)))
    }
}
