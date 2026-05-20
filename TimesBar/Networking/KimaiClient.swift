import Foundation

struct KimaiClient {
    let baseURL: URL
    let token: String
    let session: URLSession

    init(baseURL: URL = URL(string: "https://times.lipsum.services")!,
         token: String,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    /// Kimai's API expects HTML5 "local date and time" — `yyyy-MM-dd'T'HH:mm:ss` with no
    /// timezone offset. Kimai then applies the user's configured timezone server-side.
    /// Sending full ISO 8601 (with `Z` or `+02:00`) is *not* guaranteed to work and yields
    /// empty filter results on some Kimai versions.
    private static let kimaiLocalFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private func request(_ path: String,
                         method: String = "GET",
                         queryItems: [URLQueryItem]? = nil,
                         body: Data? = nil) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        if let queryItems { components.queryItems = queryItems }
        var req = URLRequest(url: components.url!)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    func ping() async throws {
        _ = try await session.data(for: request("/api/ping"))
    }

    func active() async throws -> [TimesheetEntity] {
        let (data, _) = try await session.data(for: request("/api/timesheets/active"))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }

    func stop(id: Int) async throws -> TimesheetEntity {
        let (data, _) = try await session.data(
            for: request("/api/timesheets/\(id)/stop", method: "PATCH"))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    func projects() async throws -> [ProjectEntity] {
        let items = [URLQueryItem(name: "visible", value: "1")]
        let (data, _) = try await session.data(for: request("/api/projects", queryItems: items))
        return try JSONDecoder.kimai.decode([ProjectEntity].self, from: data)
    }

    func activities() async throws -> [ActivityEntity] {
        let items = [URLQueryItem(name: "visible", value: "1")]
        let (data, _) = try await session.data(for: request("/api/activities", queryItems: items))
        return try JSONDecoder.kimai.decode([ActivityEntity].self, from: data)
    }

    func recent() async throws -> [TimesheetEntity] {
        let (data, _) = try await session.data(for: request("/api/timesheets/recent"))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }

    /// Create a stopped timesheet entry with explicit begin + end. Used by the
    /// import tool for backfilling historical CSV data.
    func createTimesheet(begin: Date,
                         end: Date,
                         project: Int,
                         activity: Int,
                         description: String?) async throws -> TimesheetEntity {
        var payload: [String: Any] = [
            "project": project,
            "activity": activity,
            "begin": Self.kimaiLocalFormatter.string(from: begin),
            "end": Self.kimaiLocalFormatter.string(from: end),
        ]
        if let description, !description.isEmpty { payload["description"] = description }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(
            for: request("/api/timesheets", method: "POST", body: body))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    func start(project: Int, activity: Int, description: String?) async throws -> TimesheetEntity {
        var payload: [String: Any] = [
            "project": project,
            "activity": activity,
            "begin": Self.kimaiLocalFormatter.string(from: Date()),
        ]
        if let description, !description.isEmpty { payload["description"] = description }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(
            for: request("/api/timesheets", method: "POST", body: body))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    /// Calendar year of the user's earliest timesheet, or nil if there are none.
    /// Uses `orderBy=begin&order=ASC&size=1` for a one-row response.
    func firstTimesheetYear() async throws -> Int? {
        let items = [
            URLQueryItem(name: "orderBy", value: "begin"),
            URLQueryItem(name: "order", value: "ASC"),
            URLQueryItem(name: "size", value: "1"),
        ]
        let (data, _) = try await session.data(
            for: request("/api/timesheets", queryItems: items))
        let entries = try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
        guard let first = entries.first else { return nil }
        return Calendar.current.component(.year, from: first.begin)
    }

    func publicHolidays(begin: Date, end: Date) async throws -> [PublicHoliday] {
        let items = [
            URLQueryItem(name: "begin", value: Self.kimaiLocalFormatter.string(from: begin)),
            URLQueryItem(name: "end", value: Self.kimaiLocalFormatter.string(from: end)),
        ]
        let (data, _) = try await session.data(
            for: request("/api/public-holidays", queryItems: items))
        return try JSONDecoder.kimai.decode([PublicHoliday].self, from: data)
    }

    func absences(begin: Date, end: Date, status: String = "approved") async throws -> [Absence] {
        let items = [
            URLQueryItem(name: "begin", value: Self.kimaiLocalFormatter.string(from: begin)),
            URLQueryItem(name: "end", value: Self.kimaiLocalFormatter.string(from: end)),
            URLQueryItem(name: "status", value: status),
        ]
        let (data, _) = try await session.data(
            for: request("/api/absences", queryItems: items))
        return try JSONDecoder.kimai.decode([Absence].self, from: data)
    }

    func timesheets(begin: Date, end: Date, size: Int = 500) async throws -> [TimesheetEntity] {
        let items = [
            URLQueryItem(name: "begin", value: Self.kimaiLocalFormatter.string(from: begin)),
            URLQueryItem(name: "end", value: Self.kimaiLocalFormatter.string(from: end)),
            URLQueryItem(name: "size", value: String(size)),
        ]
        let (data, _) = try await session.data(
            for: request("/api/timesheets", queryItems: items))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }
}
