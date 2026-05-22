import SwiftUI

/// Edit the currently running timer in place. PATCHes /api/timesheets/{id},
/// so changing project/activity does NOT restart the entry — the same row is
/// updated and the elapsed counter keeps ticking against the (possibly new)
/// begin time.
struct EditActiveTimerForm: View {
    @EnvironmentObject var store: TimerStore
    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var projectId: Int?
    @State private var activityId: Int?
    @State private var description: String = ""
    @State private var begin: Date = Date()
    /// Dummy binding for TimeRangeBar's `end` parameter in `.beginOnly` mode.
    /// Never read — the bar derives the visual end from "now" itself.
    @State private var dummyEnd: Date = Date()
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var initialProjectId: Int = -1
    @State private var initialActivityId: Int = -1
    @State private var initialDescription: String = ""
    @State private var initialBegin: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Edit running timer")
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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                TimeRangeBar(
                    day: begin,
                    mode: .beginOnly,
                    begin: $begin,
                    end: $dummyEnd,
                    existingEntries: store.nearbyEntries,
                    excludeEntryId: store.active?.id
                )

                HStack(spacing: 16) {
                    TimeNudgeField(
                        label: "Begin",
                        date: $begin,
                        maxDate: Date().addingTimeInterval(-60))
                    Spacer()
                    Text(elapsedString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(action: save) {
                    Label(isSaving ? "Saving…" : "Save",
                          systemImage: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .disabled(!canSave)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            hydrate()
            Task { await store.refreshNearbyEntries(around: begin) }
        }
        .onDisappear {
            store.clearNearbyEntries()
        }
    }

    private func hydrate() {
        guard let active = store.active else { return }
        projectId = active.project
        activityId = active.activity
        description = active.description ?? ""
        begin = active.begin
        initialProjectId = active.project
        initialActivityId = active.activity
        initialDescription = active.description ?? ""
        initialBegin = active.begin
    }

    private var sortedProjects: [(Int, String)] {
        store.projectTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private var sortedActivities: [(Int, String)] {
        store.activityTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private var elapsedString: String {
        let secs = max(0, Int(Date().timeIntervalSince(begin)))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return String(format: "%dh %02dm elapsed", h, m)
    }

    private var hint: String {
        let beginChanged = abs(begin.timeIntervalSince(initialBegin)) > 1
        let categoryChanged = projectId != initialProjectId
            || activityId != initialActivityId
        if beginChanged && categoryChanged {
            return "Updates the running entry in place. Elapsed time will recalculate."
        }
        if beginChanged {
            return "Elapsed time will recalculate from the new begin."
        }
        if categoryChanged {
            return "Updates the running entry in place — no restart, elapsed keeps ticking."
        }
        return "Drag the green handle to shift begin. Use ± buttons for ±1min nudges."
    }

    private var canSave: Bool {
        guard !isSaving, projectId != nil, activityId != nil else { return false }
        return projectId != initialProjectId
            || activityId != initialActivityId
            || description.trimmingCharacters(in: .whitespacesAndNewlines)
                != initialDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            || abs(begin.timeIntervalSince(initialBegin)) > 1
    }

    private func save() {
        guard let p = projectId, let a = activityId else { return }
        isSaving = true
        errorMessage = nil
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInitial = initialDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let projectArg: Int? = p == initialProjectId ? nil : p
        let activityArg: Int? = a == initialActivityId ? nil : a
        let beginArg: Date? = abs(begin.timeIntervalSince(initialBegin)) > 1 ? begin : nil
        let descArg: String? = trimmed == trimmedInitial ? nil : trimmed

        Task {
            let ok = await store.updateActiveTimer(
                begin: beginArg,
                project: projectArg,
                activity: activityArg,
                description: descArg)
            isSaving = false
            if ok {
                onSaved()
            } else {
                errorMessage = "Kimai rejected the edit. The activity may not belong to that project."
            }
        }
    }
}
