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
        let (data, _) = try await session.data(for: request("/api/projects"))
        return try JSONDecoder.kimai.decode([ProjectEntity].self, from: data)
    }

    func activities() async throws -> [ActivityEntity] {
        let (data, _) = try await session.data(for: request("/api/activities"))
        return try JSONDecoder.kimai.decode([ActivityEntity].self, from: data)
    }

    func recent() async throws -> [TimesheetEntity] {
        let (data, _) = try await session.data(for: request("/api/timesheets/recent"))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }

    func start(project: Int, activity: Int, description: String?) async throws -> TimesheetEntity {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var payload: [String: Any] = [
            "project": project,
            "activity": activity,
            "begin": formatter.string(from: Date()),
        ]
        if let description, !description.isEmpty { payload["description"] = description }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, _) = try await session.data(
            for: request("/api/timesheets", method: "POST", body: body))
        return try JSONDecoder.kimai.decode(TimesheetEntity.self, from: data)
    }

    func timesheets(begin: Date, end: Date, size: Int = 500) async throws -> [TimesheetEntity] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let items = [
            URLQueryItem(name: "begin", value: formatter.string(from: begin)),
            URLQueryItem(name: "end", value: formatter.string(from: end)),
            URLQueryItem(name: "size", value: String(size)),
        ]
        let (data, _) = try await session.data(
            for: request("/api/timesheets", queryItems: items))
        return try JSONDecoder.kimai.decode([TimesheetEntity].self, from: data)
    }
}
