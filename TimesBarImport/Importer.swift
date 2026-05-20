import Foundation

enum Importer {
    struct ProjectMap: Codable {
        let project: Int
        let activity: Int
    }

    static func listHolidays(year: Int, client: KimaiClient) async throws {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        guard let begin = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1))
        else { return }
        let holidays = try await client.publicHolidays(begin: begin, end: end)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = .current
        print("Public holidays returned by Kimai for \(year):")
        if holidays.isEmpty {
            print("  (none)")
        } else {
            for h in holidays.sorted(by: { $0.date < $1.date }) {
                let half = h.halfDay ? " [half-day]" : ""
                print("  \(df.string(from: h.date))  \(h.name)\(half)")
            }
        }
    }

    static func listProjects(client: KimaiClient) async throws {
        let projects = try await client.projects()
        let activities = try await client.activities()

        print("Kimai projects (visible):")
        for p in projects.sorted(by: { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }) {
            print(String(format: "  id=%-4d  %@", p.id, p.displayTitle))
        }
        print("\nKimai activities (visible):")
        for a in activities.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            print(String(format: "  id=%-4d  %@", a.id, a.name))
        }
    }

    /// Print unique TimeBuzzer projects in the CSV alongside Kimai's projects
    /// + activities, plus a starter mapping JSON the user can save and edit.
    static func printMappingTemplate(csvURL: URL, client: KimaiClient) async throws {
        let rows = try CSVParser.parse(csvURL)
        let uniqueProjects = Array(Set(rows.map(\.projectName))).sorted()

        print("Unique TimeBuzzer projects in \(csvURL.lastPathComponent):")
        for name in uniqueProjects { print("  \(name)") }
        print("")
        try await listProjects(client: client)

        print("\nMapping template (save as mapping.json, then fill in real IDs):")
        print("{")
        for (i, name) in uniqueProjects.enumerated() {
            let comma = i == uniqueProjects.count - 1 ? "" : ","
            let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
            print("  \"\(escaped)\": { \"project\": 0, \"activity\": 0 }\(comma)")
        }
        print("}")
        print("")
        print("Then rerun with: timesbar-import --csv \(csvURL.path) --mapping mapping.json --dry-run")
    }

    static func runImport(csvURL: URL, mappingURL: URL, client: KimaiClient, dryRun: Bool) async throws {
        let rows = try CSVParser.parse(csvURL)
        let mappingData = try Data(contentsOf: mappingURL)
        let mapping = try JSONDecoder().decode([String: ProjectMap].self, from: mappingData)

        // Validate mapping covers every project in the CSV
        let csvProjects = Set(rows.map(\.projectName))
        let missing = csvProjects.subtracting(mapping.keys)
        if !missing.isEmpty {
            print("Mapping missing entries for:")
            for name in missing.sorted() { print("  \(name)") }
            print("Fix mapping.json and rerun.")
            exit(1)
        }

        // Compute query range covering every CSV row (+1 day buffer either side)
        let allDates = rows.flatMap { [$0.begin, $0.end] }
        guard let minDate = allDates.min(), let maxDate = allDates.max() else {
            print("No rows in CSV.")
            return
        }
        let cal = Calendar.current
        let queryStart = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: minDate))!
        let queryEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: maxDate))!

        print("Range: \(format(queryStart)) to \(format(queryEnd))")
        print("Fetching existing Kimai timesheets in that range...")
        let existing = try await client.timesheets(begin: queryStart, end: queryEnd, size: 500)
        let existingKeys = Set(existing.map { dedupKey(begin: $0.begin, projectId: $0.project) })
        print("Found \(existing.count) existing entries. CSV has \(rows.count) rows.")
        if dryRun { print("DRY RUN — no POSTs will be made.\n") } else { print("") }

        var posted = 0, skipped = 0, errors = 0
        for row in rows.sorted(by: { $0.begin < $1.begin }) {
            let map = mapping[row.projectName]!
            let key = dedupKey(begin: row.begin, projectId: map.project)
            if existingKeys.contains(key) {
                print("  SKIP dup     \(format(row.begin))  \(row.projectName)")
                skipped += 1
                continue
            }
            if dryRun {
                print("  WOULD POST   \(format(row.begin))  →  \(format(row.end))  \(row.projectName)")
                posted += 1
                continue
            }
            do {
                _ = try await client.createTimesheet(
                    begin: row.begin,
                    end: row.end,
                    project: map.project,
                    activity: map.activity,
                    description: row.note.isEmpty ? nil : row.note
                )
                print("  POSTED       \(format(row.begin))  →  \(format(row.end))  \(row.projectName)")
                posted += 1
            } catch {
                print("  ERROR        \(format(row.begin))  \(error)")
                errors += 1
            }
        }
        print("\nDone. \(posted) \(dryRun ? "would post" : "posted"), \(skipped) skipped, \(errors) errors.")
    }

    /// Dedup key: minute-precision begin timestamp + project id.
    private static func dedupKey(begin: Date, projectId: Int) -> String {
        let minute = floor(begin.timeIntervalSince1970 / 60) * 60
        return "\(Int(minute))_\(projectId)"
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }
}
