import Foundation

extension JSONDecoder {
    static let kimai: JSONDecoder = {
        let decoder = JSONDecoder()
        let primary = ISO8601DateFormatter()
        primary.formatOptions = [.withInternetDateTime]
        let withColon = ISO8601DateFormatter()
        withColon.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        let dateOnly: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            return f
        }()

        // ISO8601DateFormatter is not Sendable; capture via nonisolated(unsafe)
        // so Swift 6's strict-concurrency check doesn't warn here. The static
        // initialiser runs once; these formatters are never mutated after that.
        nonisolated(unsafe) let sendablePrimary = primary
        nonisolated(unsafe) let sendableWithColon = withColon

        decoder.dateDecodingStrategy = .custom { container in
            let raw = try container.singleValueContainer().decode(String.self)
            if let date = sendablePrimary.date(from: raw) { return date }
            if let date = sendableWithColon.date(from: raw) { return date }
            if let date = dateOnly.date(from: raw) { return date }   // absences may be date-only
            throw DecodingError.dataCorruptedError(
                in: try container.singleValueContainer(),
                debugDescription: "Unparseable Kimai date: \(raw)")
        }
        return decoder
    }()
}
