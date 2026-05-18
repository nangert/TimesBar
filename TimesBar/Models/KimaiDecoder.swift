import Foundation

extension JSONDecoder {
    static let kimai: JSONDecoder = {
        let decoder = JSONDecoder()
        let primary = ISO8601DateFormatter()
        primary.formatOptions = [.withInternetDateTime]
        let withColon = ISO8601DateFormatter()
        withColon.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]

        decoder.dateDecodingStrategy = .custom { container in
            let raw = try container.singleValueContainer().decode(String.self)
            if let date = primary.date(from: raw) { return date }
            if let date = withColon.date(from: raw) { return date }
            throw DecodingError.dataCorruptedError(
                in: try container.singleValueContainer(),
                debugDescription: "Unparseable Kimai date: \(raw)")
        }
        return decoder
    }()
}
