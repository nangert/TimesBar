import Foundation

struct ProjectEntity: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let parentTitle: String?

    var displayTitle: String {
        if let parent = parentTitle, !parent.isEmpty {
            return "\(parent) · \(name)"
        }
        return name
    }
}
