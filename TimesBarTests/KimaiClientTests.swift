import Testing
import Foundation
@testable import TimesBar

/// All tests in this suite share `MockURLProtocol.handler`, which is a global
/// `static var`. Running them in parallel produces flaky failures when one
/// test overwrites another test's handler mid-flight. Serialize the suite.
@Suite(.serialized)
struct KimaiClientTests {

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
            // Empty page short-circuits the pagination loop after one request.
            return (response, Data("[]".utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        let begin = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_700_604_800)
        _ = try await client.timesheets(begin: begin, end: end, pageSize: 250)

        let url = try #require(captured?.url)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let names = components.queryItems?.map(\.name) ?? []
        #expect(names.contains("begin"))
        #expect(names.contains("end"))
        #expect(names.contains("size"))
        #expect(names.contains("page"))
        #expect(components.queryItems?.first(where: { $0.name == "size" })?.value == "250")
        #expect(components.queryItems?.first(where: { $0.name == "page" })?.value == "1")

        // Kimai requires HTML5 local datetime — no `Z`, no `+0000`.
        let beginValue = try #require(components.queryItems?.first(where: { $0.name == "begin" })?.value)
        #expect(!beginValue.contains("Z"))
        #expect(!beginValue.contains("+"))
        #expect(beginValue.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$"#,
                                  options: .regularExpression) != nil)
    }

    @Test func startBodyUsesHTML5LocalDateTime() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let session = mockSession { req in
            captured = req
            let body = """
            {"id":7,"project":1,"activity":2,"begin":"2026-05-19T11:00:00+0200","end":null,"description":null}
            """
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        _ = try await client.start(project: 1, activity: 2, description: nil)

        let bodyData = try #require(captured).capturedBody()
        let decoded = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let begin = try #require(decoded?["begin"] as? String)
        #expect(!begin.contains("Z"))
        #expect(!begin.contains("+"))
        #expect(begin.range(of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$"#,
                             options: .regularExpression) != nil)
    }

    // MARK: - Absences

    @Test func createAbsenceSendsPostWithDateAndType() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let session = mockSession { req in
            captured = req
            let body = """
            [{"id":42,"date":"2026-08-05","type":"holiday","status":"new","halfDay":false}]
            """
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let date = cal.date(from: DateComponents(year: 2026, month: 8, day: 5))!

        let created = try await client.createAbsence(
            user: 7,
            date: date,
            end: nil,
            type: "holiday",
            halfDay: false,
            comment: "Vacation")

        #expect(captured?.httpMethod == "POST")
        #expect(captured?.url?.path == "/api/absences")
        #expect(created.count == 1)
        #expect(created[0].id == 42)

        let bodyData = try #require(captured).capturedBody()
        let decoded = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        #expect(decoded?["user"] as? Int == 7)
        #expect(decoded?["date"] as? String == "2026-08-05")
        #expect(decoded?["type"] as? String == "holiday")
        #expect(decoded?["halfDay"] as? Bool == false)
        #expect(decoded?["comment"] as? String == "Vacation")
        #expect(decoded?["end"] == nil)
    }

    @Test func createAbsenceIncludesEndDateWhenProvided() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let session = mockSession { req in
            captured = req
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let begin = cal.date(from: DateComponents(year: 2026, month: 8, day: 5))!
        let end = cal.date(from: DateComponents(year: 2026, month: 8, day: 9))!

        _ = try await client.createAbsence(
            user: 7, date: begin, end: end, type: "holiday",
            halfDay: false, comment: nil)

        let bodyData = try #require(captured).capturedBody()
        let decoded = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        #expect(decoded?["date"] as? String == "2026-08-05")
        #expect(decoded?["end"] as? String == "2026-08-09")
        // Empty comment is omitted from the payload.
        #expect(decoded?["comment"] == nil)
    }

    @Test func createAbsenceHalfDayTogglePropagates() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let session = mockSession { req in
            captured = req
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("[]".utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        _ = try await client.createAbsence(
            user: 7, date: Date(), end: nil, type: "holiday",
            halfDay: true, comment: nil)

        let bodyData = try #require(captured).capturedBody()
        let decoded = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        #expect(decoded?["halfDay"] as? Bool == true)
    }

    @Test func deleteAbsenceSendsDeleteToCorrectPath() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let session = mockSession { req in
            captured = req
            let response = HTTPURLResponse(url: req.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = KimaiClient(token: "t", session: session)
        try await client.deleteAbsence(id: 123)

        #expect(captured?.httpMethod == "DELETE")
        #expect(captured?.url?.path == "/api/absences/123")
    }

    // MARK: - Restart

    @Test func restartSendsPatchWithCopyAll() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let session = mockSession { req in
            captured = req
            let body = """
            {"id":555,"project":1,"activity":2,"begin":"2026-05-20T11:00:00+0200","end":null,"description":"copied"}
            """
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        let entry = try await client.restart(id: 99)

        #expect(captured?.httpMethod == "PATCH")
        #expect(captured?.url?.path == "/api/timesheets/99/restart")
        #expect(entry.id == 555)

        let bodyData = try #require(captured).capturedBody()
        let decoded = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        #expect(decoded?["copy"] as? String == "all")
    }

    @Test func restartWithoutCopySendsEmptyBody() async throws {
        nonisolated(unsafe) var captured: URLRequest?
        let session = mockSession { req in
            captured = req
            let body = """
            {"id":1,"project":1,"activity":1,"begin":"2026-05-20T11:00:00+0200","end":null,"description":null}
            """
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        _ = try await client.restart(id: 99, copyAll: false)

        #expect(captured?.httpMethod == "PATCH")
        let bodyData = try #require(captured).capturedBody()
        #expect(bodyData.isEmpty)
    }

    // MARK: - Pagination

    @Test func timesheetsPagesUntilShortPageReturned() async throws {
        // Two full pages (size=2 each) then a half page (size=1) → 5 total.
        nonisolated(unsafe) var calls = 0
        let session = mockSession { req in
            calls += 1
            let body: String
            switch calls {
            case 1: body = """
                [{"id":1,"project":1,"activity":1,"begin":"2026-05-01T09:00:00+0200","end":"2026-05-01T10:00:00+0200","description":null},
                 {"id":2,"project":1,"activity":1,"begin":"2026-05-01T11:00:00+0200","end":"2026-05-01T12:00:00+0200","description":null}]
                """
            case 2: body = """
                [{"id":3,"project":1,"activity":1,"begin":"2026-05-02T09:00:00+0200","end":"2026-05-02T10:00:00+0200","description":null},
                 {"id":4,"project":1,"activity":1,"begin":"2026-05-02T11:00:00+0200","end":"2026-05-02T12:00:00+0200","description":null}]
                """
            default: body = """
                [{"id":5,"project":1,"activity":1,"begin":"2026-05-03T09:00:00+0200","end":"2026-05-03T10:00:00+0200","description":null}]
                """
            }
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        let entries = try await client.timesheets(
            begin: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 1),
            pageSize: 2)
        #expect(entries.count == 5)
        #expect(calls == 3)
        #expect(entries.map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test func timesheetsStopsOn404PastEnd() async throws {
        // Some Kimai versions answer "page past end" with 404 instead of [].
        nonisolated(unsafe) var calls = 0
        let session = mockSession { req in
            calls += 1
            if calls == 1 {
                let body = """
                [{"id":1,"project":1,"activity":1,"begin":"2026-05-01T09:00:00+0200","end":"2026-05-01T10:00:00+0200","description":null},
                 {"id":2,"project":1,"activity":1,"begin":"2026-05-01T11:00:00+0200","end":"2026-05-01T12:00:00+0200","description":null}]
                """
                let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(body.utf8))
            }
            let response = HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        let entries = try await client.timesheets(
            begin: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 1),
            pageSize: 2)
        #expect(entries.count == 2)
        #expect(calls == 2)
    }

    // MARK: - Error handling

    @Test func unauthorizedResponseThrowsTypedError() async {
        let session = mockSession { req in
            let response = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"message":"Invalid credentials"}"#.utf8))
        }
        let client = KimaiClient(token: "bad", session: session)
        do {
            _ = try await client.active()
            Issue.record("Expected KimaiError.unauthorized to be thrown")
        } catch KimaiError.unauthorized {
            // pass
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func forbiddenResponseThrowsUnauthorized() async {
        let session = mockSession { req in
            let response = HTTPURLResponse(url: req.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        do {
            _ = try await client.active()
            Issue.record("Expected KimaiError.unauthorized")
        } catch KimaiError.unauthorized {
            // pass
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test func serverErrorReturnsTypedError() async throws {
        let session = mockSession { req in
            let response = HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data(#"{"error":"oops"}"#.utf8))
        }
        let client = KimaiClient(token: "t", session: session)
        do {
            _ = try await client.active()
            Issue.record("Expected KimaiError.server")
        } catch let KimaiError.server(status, body) {
            #expect(status == 500)
            #expect(body?.contains("oops") == true)
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }
}
