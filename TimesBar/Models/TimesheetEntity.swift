import Foundation

struct TimesheetEntity: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let project: Int
    let activity: Int
    let begin: Date
    let end: Date?
    let description: String?

    init(id: Int, project: Int, activity: Int, begin: Date, end: Date?, description: String?) {
        self.id = id
        self.project = project
        self.activity = activity
        self.begin = begin
        self.end = end
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case id, project, activity, begin, end, description
    }

    private enum IdKey: String, CodingKey { case id }

    /// Kimai's `/api/timesheets` collection returns `project`/`activity` as bare integer IDs,
    /// but `/api/timesheets/active`, `/api/timesheets/recent`, and the single-entity endpoints
    /// return them as nested `{ id, name, ... }` objects. Accept both.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        project = try Self.decodeId(in: container, key: .project)
        activity = try Self.decodeId(in: container, key: .activity)
        begin = try container.decode(Date.self, forKey: .begin)
        end = try container.decodeIfPresent(Date.self, forKey: .end)
        description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    private static func decodeId(in container: KeyedDecodingContainer<CodingKeys>,
                                 key: CodingKeys) throws -> Int {
        if let plain = try? container.decode(Int.self, forKey: key) {
            return plain
        }
        let nested = try container.nestedContainer(keyedBy: IdKey.self, forKey: key)
        return try nested.decode(Int.self, forKey: .id)
    }
}
