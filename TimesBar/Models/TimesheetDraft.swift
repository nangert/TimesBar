import Foundation

/// Editable snapshot of a timesheet's fields, plus the diff rules the edit
/// forms share: what counts as "changed", and which arguments belong in a
/// minimal PATCH. Begin/end compare with a 1-second tolerance (drag snapping
/// produces sub-second noise), descriptions compare trimmed, and tags compare
/// order-insensitively.
struct TimesheetDraft: Equatable {
    var projectId: Int?
    var activityId: Int?
    var description = ""
    var tags: [String] = []
    var begin = Date()
    var end = Date()

    init() {}

    /// Hydrate from a server entity. A missing end (running entry) falls back
    /// to begin + 1h so range-based UI always has a concrete value; the edit
    /// flows that PATCH a running entry never send the end field anyway.
    init(entry: TimesheetEntity) {
        projectId = entry.project
        activityId = entry.activity
        description = entry.description ?? ""
        tags = entry.tags
        begin = entry.begin
        end = entry.end ?? entry.begin.addingTimeInterval(3600)
    }

    /// Arguments for a minimal PATCH — nil for every field equal to `initial`.
    struct PatchArgs: Equatable {
        var project: Int?
        var activity: Int?
        var begin: Date?
        var end: Date?
        var description: String?
        var tags: [String]?

        var isEmpty: Bool {
            project == nil && activity == nil && begin == nil
                && end == nil && description == nil && tags == nil
        }
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func patchArgs(from initial: TimesheetDraft) -> PatchArgs {
        PatchArgs(
            project: projectId == initial.projectId ? nil : projectId,
            activity: activityId == initial.activityId ? nil : activityId,
            begin: abs(begin.timeIntervalSince(initial.begin)) > 1 ? begin : nil,
            end: abs(end.timeIntervalSince(initial.end)) > 1 ? end : nil,
            description: trimmedDescription == initial.trimmedDescription
                ? nil : trimmedDescription,
            tags: tags.sorted() == initial.tags.sorted() ? nil : tags)
    }

    /// True when any field differs from `initial` under the form rules —
    /// drives the Save button's enabled state.
    func differs(from initial: TimesheetDraft) -> Bool {
        !patchArgs(from: initial).isEmpty
    }
}
