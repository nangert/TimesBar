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
