import Foundation

struct ActivityEntity: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
}
