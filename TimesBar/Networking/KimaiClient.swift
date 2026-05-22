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

    /// Absence dates use plain `yyyy-MM-dd` (no time component). Matches the
    /// `"2025-05-24"` example in the swagger.
    private static let absenceDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
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

    /// Send a request and return the body, throwing `KimaiError.unauthorized` on 401/403
    /// or `.server` on any other non-2xx status. Decoding errors stay as
    /// `DecodingError` so we can debug payload-shape changes.
    private func send(_ req: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { return data }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw KimaiError.unauthorized
        default:
            let body = String(data: data, encoding: .utf8)
            throw KimaiError.server(status: http.statusCode, body: body)
        }
    }

    func ping() async throws {
        _ = try await send(request("/api/ping"))
    }

    func me() async throws -> UserMe {
        let data = try await send(request("/api/users/me"))
        return try JSONDecoder.kimai.decode(UserMe.self, from: data)
    }

    func active() async throws -> [TimesheetEntity] {
        let data = try await send(request("/api/timesheets/active"))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }

    func stop(id: Int) async throws -> TimesheetEntity {
        let data = try await send(
            request("/api/timesheets/\(id)/stop", method: "PATCH"))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    func projects() async throws -> [ProjectEntity] {
        let items = [URLQueryItem(name: "visible", value: "1")]
        let data = try await send(request("/api/projects", queryItems: items))
        return try JSONDecoder.kimai.decode([ProjectEntity].self, from: data)
    }

    func activities() async throws -> [ActivityEntity] {
        let items = [URLQueryItem(name: "visible", value: "1")]
        let data = try await send(request("/api/activities", queryItems: items))
        return try JSONDecoder.kimai.decode([ActivityEntity].self, from: data)
    }

    func recent() async throws -> [TimesheetEntity] {
        let data = try await send(request("/api/timesheets/recent"))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }

    /// Create a timesheet entry with explicit begin and optional end. When `end`
    /// is nil the entry is created in the running state — Kimai then treats it
    /// as the user's active timer (it will reject a second concurrent active
    /// entry). Used by the CSV backfill import tool and by the menu bar's
    /// "log past entry" form.
    func createTimesheet(begin: Date,
                         end: Date?,
                         project: Int,
                         activity: Int,
                         description: String?) async throws -> TimesheetEntity {
        var payload: [String: Any] = [
            "project": project,
            "activity": activity,
            "begin": Self.kimaiLocalFormatter.string(from: begin),
        ]
        if let end {
            payload["end"] = Self.kimaiLocalFormatter.string(from: end)
        }
        if let description, !description.isEmpty { payload["description"] = description }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(
            request("/api/timesheets", method: "POST", body: body))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    /// Patch a timesheet — used by the menu bar's edit-active-timer form. Any
    /// nil argument is omitted from the payload, so this works for "just shift
    /// the begin time" as well as full edits. Kimai's PATCH accepts the same
    /// `TimesheetEditForm` schema as POST.
    func updateTimesheet(id: Int,
                         project: Int? = nil,
                         activity: Int? = nil,
                         begin: Date? = nil,
                         end: Date? = nil,
                         description: String? = nil) async throws -> TimesheetEntity {
        var payload: [String: Any] = [:]
        if let project { payload["project"] = project }
        if let activity { payload["activity"] = activity }
        if let begin { payload["begin"] = Self.kimaiLocalFormatter.string(from: begin) }
        if let end { payload["end"] = Self.kimaiLocalFormatter.string(from: end) }
        if let description { payload["description"] = description }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(
            request("/api/timesheets/\(id)", method: "PATCH", body: body))
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
        let data = try await send(
            request("/api/timesheets", method: "POST", body: body))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    /// Restart a stopped timesheet — creates a *new* entry with the same
    /// customer/project/activity combo. With `copyAll: true` (the default),
    /// Kimai also copies the description and tags, which is what the menu
    /// bar's quick-start path wants — re-issuing `POST /timesheets` from
    /// scratch would lose tags.
    func restart(id: Int, copyAll: Bool = true) async throws -> TimesheetEntity {
        let body: Data?
        if copyAll {
            body = try JSONSerialization.data(withJSONObject: ["copy": "all"])
        } else {
            body = nil
        }
        let data = try await send(
            request("/api/timesheets/\(id)/restart", method: "PATCH", body: body))
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
        let data = try await send(request("/api/timesheets", queryItems: items))
        let entries = try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
        guard let first = entries.first else { return nil }
        return Calendar.current.component(.year, from: first.begin)
    }

    func publicHolidays(begin: Date, end: Date, group: Int? = nil) async throws -> [PublicHoliday] {
        var items = [
            URLQueryItem(name: "begin", value: Self.kimaiLocalFormatter.string(from: begin)),
            URLQueryItem(name: "end", value: Self.kimaiLocalFormatter.string(from: end)),
        ]
        if let group { items.append(URLQueryItem(name: "group", value: String(group))) }
        let data = try await send(
            request("/api/public-holidays", queryItems: items))
        return try JSONDecoder.kimai.decode([PublicHoliday].self, from: data)
    }

    /// Create a new absence request. Kimai returns an array — multi-day
    /// requests are expanded into one absence per day server-side.
    /// `user` is required by the API; pass `UserMe.id`.
    func createAbsence(user: Int,
                       date: Date,
                       end: Date?,
                       type: String,
                       halfDay: Bool,
                       comment: String?) async throws -> [Absence] {
        var payload: [String: Any] = [
            "user": user,
            "date": Self.absenceDateFormatter.string(from: date),
            "type": type,
            "halfDay": halfDay,
        ]
        if let end {
            payload["end"] = Self.absenceDateFormatter.string(from: end)
        }
        if let comment, !comment.isEmpty {
            payload["comment"] = comment
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await send(
            request("/api/absences", method: "POST", body: body))
        return try JSONDecoder.kimai.decode([Absence].self, from: data)
    }

    /// Delete (cancel) an absence by ID. Requires `delete_absence` permission;
    /// Kimai allows users to remove their own pending requests by default.
    func deleteAbsence(id: Int) async throws {
        _ = try await send(
            request("/api/absences/\(id)", method: "DELETE"))
    }

    func absences(begin: Date, end: Date, status: String = "approved") async throws -> [Absence] {
        let items = [
            URLQueryItem(name: "begin", value: Self.kimaiLocalFormatter.string(from: begin)),
            URLQueryItem(name: "end", value: Self.kimaiLocalFormatter.string(from: end)),
            URLQueryItem(name: "status", value: status),
        ]
        let data = try await send(
            request("/api/absences", queryItems: items))
        return try JSONDecoder.kimai.decode([Absence].self, from: data)
    }

    /// Fetch timesheets across a date range, paging until exhausted. Kimai caps
    /// each page at the `pageSize` parameter (default 100); a single page-size
    /// request would silently drop entries from heavy loggers or wide date
    /// ranges, so we always loop until a short page comes back.
    func timesheets(begin: Date,
                    end: Date,
                    pageSize: Int = 100) async throws -> [TimesheetEntity] {
        var all: [TimesheetEntity] = []
        var page = 1
        while true {
            let items = [
                URLQueryItem(name: "begin", value: Self.kimaiLocalFormatter.string(from: begin)),
                URLQueryItem(name: "end", value: Self.kimaiLocalFormatter.string(from: end)),
                URLQueryItem(name: "size", value: String(pageSize)),
                URLQueryItem(name: "page", value: String(page)),
            ]
            do {
                let data = try await send(
                    request("/api/timesheets", queryItems: items))
                let chunk = try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
                all.append(contentsOf: chunk)
                if chunk.count < pageSize { break }
            } catch KimaiError.server(status: 404, _) {
                // Kimai returns 404 instead of an empty page when you ask for
                // a page past the end. Treat as "no more results".
                break
            }
            page += 1
            if page > 1000 { break } // safety stop
        }
        return all
    }
}
