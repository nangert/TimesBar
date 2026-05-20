import Foundation

struct PublicHoliday: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let date: Date
    let name: String
    let halfDay: Bool

    var dayWeight: Double { halfDay ? 0.5 : 1.0 }

    private enum CodingKeys: String, CodingKey { case id, date, name, halfDay }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        halfDay = (try? c.decode(Bool.self, forKey: .halfDay)) ?? false
    }
}
