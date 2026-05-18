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

@Test func decodesStoppedTimesheet() throws {
    let json = """
    {"id":1,"project":1,"activity":1,"begin":"2026-05-18T09:00:00+0200","end":"2026-05-18T10:30:00+0200","description":null}
    """.data(using: .utf8)!
    let entity = try JSONDecoder.kimai.decode(TimesheetEntity.self, from: json)
    #expect(entity.end != nil)
    #expect(entity.description == nil)
}
