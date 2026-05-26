import Testing
import Foundation
@testable import TimesBar

// MARK: - URLActionRouter.parse

@Test func parse_stopURL() {
    #expect(URLActionRouter.parse(URL(string: "timesbar://stop")!) == .stop)
}

@Test func parse_startLastURL() {
    #expect(URLActionRouter.parse(URL(string: "timesbar://startLast")!) == .startLast)
}

@Test func parse_toggleURL() {
    #expect(URLActionRouter.parse(URL(string: "timesbar://toggle")!) == .toggle)
}

@Test func parse_pauseURL() {
    #expect(URLActionRouter.parse(URL(string: "timesbar://pause")!) == .pause)
}

@Test func parse_isCaseInsensitive() {
    #expect(URLActionRouter.parse(URL(string: "TIMESBAR://STOP")!) == .stop)
    #expect(URLActionRouter.parse(URL(string: "timesbar://STARTLAST")!) == .startLast)
    #expect(URLActionRouter.parse(URL(string: "timesbar://Toggle")!) == .toggle)
}

@Test func parse_acceptsPathStyle() {
    // `timesbar:stop` (no `//`) parses with the action in the path rather than the host.
    #expect(URLActionRouter.parse(URL(string: "timesbar:stop")!) == .stop)
    #expect(URLActionRouter.parse(URL(string: "timesbar:/startLast")!) == .startLast)
}

@Test func parse_rejectsForeignScheme() {
    #expect(URLActionRouter.parse(URL(string: "kimai-clock://stop")!) == nil)
    #expect(URLActionRouter.parse(URL(string: "https://example.com/stop")!) == nil)
}

@Test func parse_rejectsUnknownAction() {
    #expect(URLActionRouter.parse(URL(string: "timesbar://wat")!) == nil)
    #expect(URLActionRouter.parse(URL(string: "timesbar://")!) == nil)
}

@Test func parse_ignoresQueryAndFragment() {
    // Trailing query params (e.g. for analytics) should not break action recognition.
    #expect(URLActionRouter.parse(URL(string: "timesbar://stop?source=alfred")!) == .stop)
    #expect(URLActionRouter.parse(URL(string: "timesbar://toggle#x")!) == .toggle)
}
