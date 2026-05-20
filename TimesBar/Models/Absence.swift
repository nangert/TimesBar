import Foundation

struct Absence: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let date: Date
    let duration: Int?
    let type: String
    let status: String?
    let halfDay: Bool

    /// 0.5 for half-day absences, 1.0 otherwise. We weigh by row + the
    /// `halfDay` flag rather than by `duration` because the duration unit
    /// (seconds vs minutes) isn't pinned down in the Kimai swagger and
    /// varies between contract-bundle versions.
    var dayWeight: Double { halfDay ? 0.5 : 1.0 }

    private enum CodingKeys: String, CodingKey {
        case id, date, duration, type, status, halfDay
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        duration = try c.decodeIfPresent(Int.self, forKey: .duration)
        type = (try? c.decode(String.self, forKey: .type)) ?? "other"
        status = try c.decodeIfPresent(String.self, forKey: .status)
        halfDay = (try? c.decode(Bool.self, forKey: .halfDay)) ?? false
    }

    // Memberwise initializer for tests.
    init(id: Int, date: Date, duration: Int?, type: String, status: String?, halfDay: Bool) {
        self.id = id
        self.date = date
        self.duration = duration
        self.type = type
        self.status = status
        self.halfDay = halfDay
    }
}
