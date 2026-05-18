import SwiftUI

struct StartTimerSheet: View {
    @EnvironmentObject var store: TimerStore
    @Environment(\.dismiss) private var dismiss

    @State private var projectId: Int?
    @State private var activityId: Int?
    @State private var description: String = ""
    @State private var isStarting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start a new timer")
                .font(.system(size: 14, weight: .semibold))
            Text("Pick a project and activity. Both come from your Kimai install.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Picker("Project", selection: $projectId) {
                Text("Select project…").tag(Optional<Int>.none)
                ForEach(sortedProjects, id: \.0) { id, title in
                    Text(title).tag(Optional(id))
                }
            }

            Picker("Activity", selection: $activityId) {
                Text("Select activity…").tag(Optional<Int>.none)
                ForEach(sortedActivities, id: \.0) { id, name in
                    Text(name).tag(Optional(id))
                }
            }

            TextField("Description (optional)", text: $description)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Start") { startTimer() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(projectId == nil || activityId == nil || isStarting)
            }
        }
        .padding(16)
        .frame(width: 380)
    }

    private var sortedProjects: [(Int, String)] {
        store.projectTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private var sortedActivities: [(Int, String)] {
        store.activityTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private func startTimer() {
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
                dismiss()
            } else {
                errorMessage = "Kimai rejected the start request. Check that the activity belongs to the project."
            }
        }
    }
}
