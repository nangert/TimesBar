import SwiftUI

/// The four standard timesheet fields (project, activity, note, tags) shared
/// by the start / edit forms. Emits loose rows, so the parent VStack's
/// spacing applies between them exactly as when the rows were inlined.
struct TimesheetFieldsSection: View {
    @EnvironmentObject var store: TimerStore
    @Binding var projectId: Int?
    @Binding var activityId: Int?
    @Binding var description: String
    @Binding var tags: [String]

    var body: some View {
        FormRow(label: "Project") {
            InlinePicker(
                placeholder: "Select project…",
                selectionTitle: projectId.flatMap { id in
                    store.sortedProjects.first(where: { $0.0 == id })?.1
                },
                options: store.sortedProjects,
                onPick: { projectId = $0 }
            )
        }
        FormRow(label: "Activity") {
            InlinePicker(
                placeholder: "Select activity…",
                selectionTitle: activityId.flatMap { id in
                    store.sortedActivities.first(where: { $0.0 == id })?.1
                },
                options: store.sortedActivities,
                onPick: { activityId = $0 }
            )
        }
        FormRow(label: "Note") {
            TextField("Optional", text: $description)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .pillFieldStyle()
        }
        FormRow(label: "Tags") {
            TagsField(tags: $tags, suggestions: store.knownTags)
        }
    }
}
