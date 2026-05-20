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

        decoder.dateDecodingStrategy = .custom { container in
            let raw = try container.singleValueContainer().decode(String.self)
            if let date = primary.date(from: raw) { return date }
            if let date = withColon.date(from: raw) { return date }
            if let date = dateOnly.date(from: raw) { return date }   // absences may be date-only
            throw DecodingError.dataCorruptedError(
                in: try container.singleValueContainer(),
                debugDescription: "Unparseable Kimai date: \(raw)")
        }
        return decoder
    }()
}
