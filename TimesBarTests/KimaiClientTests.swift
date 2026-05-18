import Testing
import Foundation
@testable import TimesBar

@Test func pingHitsCorrectPathWithBearerToken() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data("{}".utf8))
    }
    let client = KimaiClient(token: "abc123", session: session)

    try await client.ping()

    #expect(captured?.url?.path == "/api/ping")
    #expect(captured?.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
}

@Test func activeReturnsDecodedTimesheets() async throws {
    let session = mockSession { req in
        let body = """
        [{"id":1,"project":7,"activity":3,"begin":"2026-05-18T09:30:00+0200","end":null,"description":"x"}]
        """
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    let entries = try await client.active()
    #expect(entries.count == 1)
    #expect(entries[0].id == 1)
}

@Test func stopUsesPatchAndCorrectPath() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let body = """
        {"id":99,"project":7,"activity":3,"begin":"2026-05-18T09:00:00+0200","end":"2026-05-18T10:00:00+0200","description":null}
        """
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    _ = try await client.stop(id: 99)

    #expect(captured?.httpMethod == "PATCH")
    #expect(captured?.url?.path == "/api/timesheets/99/stop")
}

@Test func recentHitsCorrectPath() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data("[]".utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    _ = try await client.recent()
    #expect(captured?.url?.path == "/api/timesheets/recent")
}

@Test func startSendsPostWithJSONBody() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let body = """
        {"id":7,"project":1,"activity":2,"begin":"2026-05-18T11:00:00+0200","end":null,"description":null}
        """
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data(body.utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    _ = try await client.start(project: 1, activity: 2, description: "hi")

    #expect(captured?.httpMethod == "POST")
    #expect(captured?.url?.path == "/api/timesheets")
    let bodyData = try #require(captured).capturedBody()
    let decoded = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
    #expect(decoded?["project"] as? Int == 1)
    #expect(decoded?["activity"] as? Int == 2)
}

@Test func timesheetsBuildsQueryStringWithDates() async throws {
    nonisolated(unsafe) var captured: URLRequest?
    let session = mockSession { req in
        captured = req
        let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (response, Data("[]".utf8))
    }
    let client = KimaiClient(token: "t", session: session)
    let begin = Date(timeIntervalSince1970: 1_700_000_000)
    let end = Date(timeIntervalSince1970: 1_700_604_800)
    _ = try await client.timesheets(begin: begin, end: end, size: 250)

    let url = try #require(captured?.url)
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
    let names = components.queryItems?.map(\.name) ?? []
    #expect(names.contains("begin"))
    #expect(names.contains("end"))
    #expect(names.contains("size"))
    #expect(components.queryItems?.first(where: { $0.name == "size" })?.value == "250")
}
