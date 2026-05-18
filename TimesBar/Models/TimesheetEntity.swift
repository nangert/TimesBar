import Foundation

struct TimesheetEntity: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let project: Int
    let activity: Int
    let begin: Date
    let end: Date?
    let description: String?
}
