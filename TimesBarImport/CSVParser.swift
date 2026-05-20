import Foundation

struct TimeBuzzerRow {
    let teamMember: String
    let customer: String
    let projectName: String   // TimeBuzzer's "Projekte" column
    let note: String
    let begin: Date
    let end: Date
}

enum CSVParser {
    static func parse(_ url: URL) throws -> [TimeBuzzerRow] {
        let raw = try String(contentsOf: url, encoding: .utf8)
        // Strip BOM if present
        let stripped = raw.hasPrefix("\u{FEFF}") ? String(raw.dropFirst()) : raw
        // Character.isNewline handles \n, \r, and the \r\n grapheme cluster.
        let lines = stripped.split(whereSeparator: \.isNewline).map(String.init)
        guard lines.count > 1 else { return [] }

        var rows: [TimeBuzzerRow] = []
        for (idx, line) in lines.enumerated() {
            if idx == 0 { continue } // header
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let fields = parseCSVLine(trimmed)
            guard fields.count >= 8 else {
                FileHandle.standardError.write(
                    Data("Skipping row with too few columns: \(trimmed)\n".utf8))
                continue
            }

            let teamMember = fields[0]
            let customer = fields[1]
            let projectName = fields[2]
            let note = fields[3]
            let startDate = fields[4].trimmingCharacters(in: .whitespaces)
            let endDate = fields[5].trimmingCharacters(in: .whitespaces)
            let startTime = fields[6].trimmingCharacters(in: .whitespaces)
            let endTime = fields[7].trimmingCharacters(in: .whitespaces)

            guard let begin = parseGermanDateTime(date: startDate, time: startTime),
                  let end = parseGermanDateTime(date: endDate, time: endTime)
            else {
                FileHandle.standardError.write(
                    Data("Skipping row with unparseable date: \(trimmed)\n".utf8))
                continue
            }

            rows.append(TimeBuzzerRow(
                teamMember: teamMember,
                customer: customer,
                projectName: projectName,
                note: note,
                begin: begin,
                end: end
            ))
        }
        return rows
    }

    /// Minimal CSV-line parser: respects double-quoted fields, ignores commas inside quotes.
    /// Does not support escaped quotes ("") — TimeBuzzer exports don't need it.
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for c in line {
            if c == "\"" {
                inQuotes.toggle()
            } else if c == "," && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
        }
        fields.append(current)
        return fields
    }

    private static func parseGermanDateTime(date: String, time: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm"
        f.locale = Locale(identifier: "de_DE_POSIX")
        f.timeZone = .current
        return f.date(from: "\(date) \(time)")
    }
}
