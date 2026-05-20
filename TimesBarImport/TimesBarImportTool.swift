import Foundation

@main
struct TimesBarImportTool {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
            exit(1)
        }
    }

    static func run() async throws {
        var args = Array(CommandLine.arguments.dropFirst())

        if args.isEmpty || args.contains("--help") || args.contains("-h") {
            printHelp()
            return
        }

        var csvPath: String?
        var mappingPath: String?
        var token: String?
        var dryRun = false
        var listProjects = false
        var listHolidaysYear: Int?

        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "--csv":      csvPath = args.popFirstOrExit(flag: arg)
            case "--mapping":  mappingPath = args.popFirstOrExit(flag: arg)
            case "--token":    token = args.popFirstOrExit(flag: arg)
            case "--dry-run":  dryRun = true
            case "--list-projects": listProjects = true
            case "--list-holidays":
                listHolidaysYear = Int(args.popFirstOrExit(flag: arg))
            default:
                FileHandle.standardError.write(Data("Unknown argument: \(arg)\n".utf8))
                exit(1)
            }
        }

        guard let resolvedToken = resolveToken(explicit: token) else {
            FileHandle.standardError.write(Data("""
                No Kimai token available. Provide one via:
                  --token <token>
                or set KIMAI_TOKEN in your environment, e.g.:
                  export KIMAI_TOKEN=$(security find-generic-password -s bar.times.token -w)

                """.utf8))
            exit(1)
        }

        let client = KimaiClient(token: resolvedToken)

        if listProjects {
            try await Importer.listProjects(client: client)
            return
        }
        if let year = listHolidaysYear {
            try await Importer.listHolidays(year: year, client: client)
            return
        }

        guard let csvPath else {
            FileHandle.standardError.write(Data("--csv <path> is required.\n".utf8))
            exit(1)
        }
        let csvURL = URL(fileURLWithPath: (csvPath as NSString).expandingTildeInPath)

        guard let mappingPath else {
            try await Importer.printMappingTemplate(csvURL: csvURL, client: client)
            return
        }
        let mappingURL = URL(fileURLWithPath: (mappingPath as NSString).expandingTildeInPath)

        try await Importer.runImport(csvURL: csvURL,
                                     mappingURL: mappingURL,
                                     client: client,
                                     dryRun: dryRun)
    }

    private static func resolveToken(explicit: String?) -> String? {
        if let explicit, !explicit.isEmpty { return explicit }
        if let env = ProcessInfo.processInfo.environment["KIMAI_TOKEN"], !env.isEmpty { return env }
        // Best-effort: try the same Keychain item the app uses. This will only
        // work if the tool is signed with the same access group as the app — we
        // aren't, so this almost always returns nil. Left in for the rare case
        // it does work (custom signing).
        if let kc = TokenStore().read(), !kc.isEmpty { return kc }
        return nil
    }

    static func printHelp() {
        print("""
        timesbar-import — Import a TimeBuzzer CSV export into Kimai.

        Usage:
          timesbar-import --list-projects [--token TOKEN]
              List Kimai projects + activities so you can build a mapping file.

          timesbar-import --csv FILE [--token TOKEN]
              Print the unique TimeBuzzer projects from the CSV alongside the
              Kimai catalog, plus a starter mapping JSON.

          timesbar-import --csv FILE --mapping MAP.json [--dry-run] [--token TOKEN]
              Parse the CSV, dedupe against existing Kimai entries in the
              CSV's date range, and POST every new row. --dry-run prints what
              would happen without writing.

        Token resolution (first wins):
          --token TOKEN
          $KIMAI_TOKEN
          Keychain (only if signed with the app's access group; usually not)

        Quick start:
          export KIMAI_TOKEN=$(security find-generic-password -s bar.times.token -w)
          timesbar-import --csv ~/Downloads/file.csv
          # save the printed JSON as mapping.json, fill in IDs
          timesbar-import --csv ~/Downloads/file.csv --mapping mapping.json --dry-run
          timesbar-import --csv ~/Downloads/file.csv --mapping mapping.json
        """)
    }
}

private extension Array where Element == String {
    mutating func popFirstOrExit(flag: String) -> String {
        guard !isEmpty else {
            FileHandle.standardError.write(Data("\(flag) requires a value\n".utf8))
            exit(1)
        }
        return removeFirst()
    }
}
