import Testing
import Foundation
@testable import TimesBar

private func makeDraft() -> TimesheetDraft {
    var d = TimesheetDraft()
    d.projectId = 1
    d.activityId = 2
    d.description = "desc"
    d.tags = ["a", "b"]
    d.begin = Date(timeIntervalSince1970: 1_000_000)
    d.end = Date(timeIntervalSince1970: 1_003_600)
    return d
}

@Test func unchangedDraftProducesEmptyPatch() {
    let initial = makeDraft()
    let args = makeDraft().patchArgs(from: initial)
    #expect(args.isEmpty)
    #expect(!makeDraft().differs(from: initial))
}

@Test func changedFieldsAppearInPatchOthersStayNil() {
    let initial = makeDraft()
    var d = makeDraft()
    d.projectId = 7
    let args = d.patchArgs(from: initial)
    #expect(args.project == 7)
    #expect(args.activity == nil)
    #expect(args.begin == nil)
    #expect(args.end == nil)
    #expect(args.description == nil)
    #expect(args.tags == nil)
    #expect(d.differs(from: initial))
}

@Test func descriptionComparesTrimmedAndSendsTrimmedValue() {
    let initial = makeDraft()
    var same = makeDraft()
    same.description = "  desc  "
    #expect(!same.differs(from: initial))

    var changed = makeDraft()
    changed.description = "  new note "
    #expect(changed.patchArgs(from: initial).description == "new note")
}

@Test func tagsCompareOrderInsensitively() {
    let initial = makeDraft()
    var reordered = makeDraft()
    reordered.tags = ["b", "a"]
    #expect(!reordered.differs(from: initial))

    var cleared = makeDraft()
    cleared.tags = []
    // The empty array must be sent (not nil) so the user can clear tags.
    #expect(cleared.patchArgs(from: initial).tags == [])
}

@Test func beginAndEndUseOneSecondTolerance() {
    let initial = makeDraft()
    var subSecond = makeDraft()
    subSecond.begin = initial.begin.addingTimeInterval(0.5)
    subSecond.end = initial.end.addingTimeInterval(-0.9)
    #expect(!subSecond.differs(from: initial))

    var moved = makeDraft()
    moved.begin = initial.begin.addingTimeInterval(-300)
    let args = moved.patchArgs(from: initial)
    #expect(args.begin == moved.begin)
    #expect(args.end == nil)
}

@Test func entityInitDefaultsMissingEndToBeginPlusOneHour() {
    let begin = Date(timeIntervalSince1970: 2_000_000)
    let running = TimesheetEntity(
        id: 9, project: 1, activity: 2, begin: begin, end: nil,
        description: nil, tags: ["x"])
    let draft = TimesheetDraft(entry: running)
    #expect(draft.end == begin.addingTimeInterval(3600))
    #expect(draft.description == "")
    #expect(draft.tags == ["x"])
}
