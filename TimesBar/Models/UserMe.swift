import Foundation

/// Mirrors what `/api/users/me` returns. Only fields we actually use are
/// decoded — everything else (memberships, teams, avatar, etc.) is ignored.
struct UserMe: Decodable, Equatable, Sendable {
    let id: Int
    let alias: String?
    let preferences: [Preference]

    struct Preference: Decodable, Equatable, Sendable {
        let name: String
        let value: String?
    }

    private func preference(_ name: String) -> String? {
        preferences.first { $0.name == name }?.value
    }

    /// Stored as seconds in Kimai (`138600` = 38.5h). Convert back to hours.
    var hoursPerWeek: Double? {
        guard let raw = preference("hours_per_week"), let seconds = Int(raw) else { return nil }
        return Double(seconds) / 3600.0
    }

    /// Annual vacation budget. Plain integer string.
    var holidaysPerYear: Int? {
        guard let raw = preference("holidays") else { return nil }
        return Int(raw)
    }

    /// Public-holiday group ID — required to make /api/public-holidays return the
    /// user's actual country holidays. Without it, Kimai returns the default group
    /// which on most installs is empty.
    var publicHolidayGroupId: Int? {
        guard let raw = preference("public_holiday_group") else { return nil }
        return Int(raw)
    }

    /// Contract start date (e.g. "2024-07-01"). Used to prorate the first
    /// year's vacation budget and to compute multi-year balances.
    var workStartDate: Date? {
        guard let raw = preference("work_start_day") else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: raw)
    }
}
