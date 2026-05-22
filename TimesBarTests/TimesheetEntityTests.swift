import Testing
import Foundation
@testable import TimesBar

@Test func decodesActiveTimesheet() throws {
    let json = """
    {
      "id": 42,
      "project": 7,
      "activity": 3,
      "begin": "2026-05-18T09:30:00+0200",
      "end": null,
      "description": "Kimai API work"
    }
    """.data(using: .utf8)!

    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)

    #expect(entity.id == 42)
    #expect(entity.project == 7)
    #expect(entity.activity == 3)
    #expect(entity.end == nil)
    #expect(entity.description == "Kimai API work")
}

@Test func decodesNestedProjectActivityFromActiveEndpoint() throws {
    let json = """
    {
      "id": 261,
      "project": { "id": 7, "name": "Frontend dev", "parentTitle": "Acme Co" },
      "activity": { "id": 3, "name": "Coding" },
      "begin": "2026-05-18T15:08:00+0200",
      "end": null,
      "description": "Auth refactor",
      "user": { "id": 1, "username": "x" },
      "tags": []
    }
    """.data(using: .utf8)!

    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)

    #expect(entity.id == 261)
    #expect(entity.project == 7)
    #expect(entity.activity == 3)
    #expect(entity.description == "Auth refactor")
    #expect(entity.end == nil)
}

@Test func decodesStoppedTimesheet() throws {
    let json = """
    {"id":1,"project":1,"activity":1,"begin":"2026-05-18T09:00:00+0200","end":"2026-05-18T10:30:00+0200","description":null}
    """.data(using: .utf8)!
    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)
    #expect(entity.end != nil)
    #expect(entity.description == nil)
}

@Test func decodesTagsFromActiveEndpoint() throws {
    let json = """
    {
      "id": 99,
      "project": { "id": 2, "name": "Backend" },
      "activity": { "id": 5, "name": "Dev" },
      "begin": "2026-05-18T10:00:00+0200",
      "end": null,
      "description": null,
      "tags": ["deep-work", "meeting"]
    }
    """.data(using: .utf8)!

    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)
    #expect(entity.tags == ["deep-work", "meeting"])
}

@Test func defaultsTagsToEmptyWhenFieldAbsent() throws {
    let json = """
    {"id":1,"project":1,"activity":1,"begin":"2026-05-18T09:00:00+0200","end":null,"description":null}
    """.data(using: .utf8)!
    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)
    #expect(entity.tags.isEmpty)
}

@Test func decodesEmptyTagsArray() throws {
    let json = """
    {"id":1,"project":1,"activity":1,"begin":"2026-05-18T09:00:00+0200","end":null,"description":null,"tags":[]}
    """.data(using: .utf8)!
    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)
    #expect(entity.tags.isEmpty)
}
