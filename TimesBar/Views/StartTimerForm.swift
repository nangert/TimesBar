import SwiftUI

struct StartTimerForm: View {
    @EnvironmentObject var store: TimerStore
    let onCancel: () -> Void
    let onStarted: () -> Void

    @State private var projectId: Int?
    @State private var activityId: Int?
    @State private var description: String = ""
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "New timer")
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(2)
                }
                .buttonStyle(.plain)
            }

            FormRow(label: "Project") {
                InlinePicker(
                    placeholder: "Select project…",
                    selectionTitle: projectId.flatMap { id in
                        sortedProjects.first(where: { $0.0 == id })?.1
                    },
                    options: sortedProjects,
                    onPick: { projectId = $0 }
                )
            }

            FormRow(label: "Activity") {
                InlinePicker(
                    placeholder: "Select activity…",
                    selectionTitle: activityId.flatMap { id in
                        sortedActivities.first(where: { $0.0 == id })?.1
                    },
                    options: sortedActivities,
                    onPick: { activityId = $0 }
                )
            }

            FormRow(label: "Note") {
                TextField("Optional", text: $description)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .pillFieldStyle()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button {
                    guard let p = projectId, let a = activityId else { return }
                    isStarting = true
                    errorMessage = nil
                    Task {
                        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                        let ok = await store.startCheckingResult(
                            project: p,
                            activity: a,
                            description: trimmed.isEmpty ? nil : trimmed
                        )
                        isStarting = false
                        if ok {
                            onStarted()
                        } else {
                            errorMessage = "Kimai rejected the request. The activity may not belong to that project."
                        }
                    }
                } label: {
                    Label(isStarting ? "Starting…" : "Start", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .disabled(projectId == nil || activityId == nil || isStarting)
            }
        }
    }

    private var sortedProjects: [(Int, String)] {
        store.projectTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private var sortedActivities: [(Int, String)] {
        store.activityTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }
}
