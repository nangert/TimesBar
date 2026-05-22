import Testing
import Foundation
@testable import TimesBar

@Suite struct TagsTests {

    @Test func normalizeTrimsWhitespace() {
        let result = normalizeTags("  deep-work  ", existing: [])
        #expect(result == ["deep-work"])
    }

    @Test func normalizeSplitsOnComma() {
        let result = normalizeTags("foo,bar,baz", existing: [])
        #expect(result == ["foo", "bar", "baz"])
    }

    @Test func normalizeDeduplicatesAgainstExisting() {
        let result = normalizeTags("foo,bar", existing: ["foo"])
        #expect(result == ["bar"])
    }

    @Test func normalizeRejectsEmptyComponents() {
        let result = normalizeTags(",,,", existing: [])
        #expect(result.isEmpty)
    }

    @Test func normalizeRejectsWhitespaceOnlyComponents() {
        let result = normalizeTags("  ,  ", existing: [])
        #expect(result.isEmpty)
    }

    @Test func normalizeHandlesTrailingComma() {
        let result = normalizeTags("meeting,", existing: [])
        #expect(result == ["meeting"])
    }

    @Test func normalizeEmptyInputReturnsEmpty() {
        let result = normalizeTags("", existing: [])
        #expect(result.isEmpty)
    }
}
