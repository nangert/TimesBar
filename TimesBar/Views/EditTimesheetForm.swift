import SwiftUI

/// Edit any completed timesheet entry (not just the running one). PATCHes
/// /api/timesheets/{id} with the changed fields. Both begin and end are
/// draggable because past entries always have a finite time range.
struct EditTimesheetForm: View {
    @EnvironmentObject var store: TimerStore
    let entry: TimesheetEntity
    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var projectId: Int?
    @State private var activityId: Int?
    @State private var description: String = ""
    @State private var tags: [String] = []
    @State private var begin: Date = Date()
    @State private var end: Date = Date()
    @State private var calendarExpanded: Bool = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var initialProjectId: Int = -1
    @State private var initialActivityId: Int = -1
    @State private var initialDescription: String = ""
    @State private var initialTags: [String] = []
    @State private var initialBegin: Date = Date()
    @State private var initialEnd: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Edit entry")
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

            FormRow(label: "Tags") {
                TagsField(tags: $tags, suggestions: store.knownTags)
            }

            Divider()

            DateFieldRow(
                label: "Date",
                date: $begin,
                isExpanded: $calendarExpanded
            )
            .onChange(of: begin) { _, newBegin in
                // Keep end on the same calendar day when the user picks a
                // different date, and ensure end stays after begin.
                let cal = Calendar.current
                if !cal.isDate(end, inSameDayAs: newBegin) {
                    let comps = cal.dateComponents([.hour, .minute, .second], from: end)
                    if let migrated = cal.date(bySettingHour: comps.hour ?? 0,
                                                minute: comps.minute ?? 0,
                                                second: comps.second ?? 0,
                                                of: newBegin) {
                        end = migrated
                    }
                }
                if end <= newBegin {
                    end = newBegin.addingTimeInterval(3600)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TimeRangeBar(
                    day: begin,
                    mode: .range,
                    begin: $begin,
                    end: $end,
                    existingEntries: store.nearbyEntries,
                    excludeEntryId: entry.id,
                    colorForProject: { store.projectColor(for: $0) }
                )

                HStack(spacing: 16) {
                    TimeNudgeField(label: "Begin", date: $begin)
                    TimeNudgeField(label: "End", date: $end, minDate: begin.addingTimeInterval(60))
                    Spacer()
                    Text(durationString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

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
        .onChange(of: Calendar.current.startOfDay(for: begin)) { _, _ in
            Task { await store.refreshNearbyEntries(around: begin) }
        }
        .onDisappear {
            store.clearNearbyEntries()
        }
    }

    // MARK: - Helpers

    private func hydrate() {
        projectId = entry.project
        activityId = entry.activity
        description = entry.description ?? ""
        tags = entry.tags
        begin = entry.begin
        end = entry.end ?? entry.begin.addingTimeInterval(3600)
        initialProjectId = entry.project
        initialActivityId = entry.activity
        initialDescription = entry.description ?? ""
        initialTags = entry.tags
        initialBegin = entry.begin
        initialEnd = entry.end ?? entry.begin.addingTimeInterval(3600)
    }

    private var sortedProjects: [(Int, String)] {
        store.projectTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private var sortedActivities: [(Int, String)] {
        store.activityTitles.map { ($0.key, $0.value) }
            .sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private var durationString: String {
        let seconds = max(0, end.timeIntervalSince(begin))
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private var canSave: Bool {
        guard !isSaving, projectId != nil, activityId != nil else { return false }
        guard end > begin else { return false }
        return projectId != initialProjectId
            || activityId != initialActivityId
            || description.trimmingCharacters(in: .whitespacesAndNewlines)
                != initialDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            || tags.sorted() != initialTags.sorted()
            || abs(begin.timeIntervalSince(initialBegin)) > 1
            || abs(end.timeIntervalSince(initialEnd)) > 1
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
        let endArg: Date? = abs(end.timeIntervalSince(initialEnd)) > 1 ? end : nil
        let descArg: String? = trimmed == trimmedInitial ? nil : trimmed
        let tagsArg: [String]? = tags.sorted() == initialTags.sorted() ? nil : tags

        Task {
            let ok = await store.updateTimesheet(
                id: entry.id,
                project: projectArg,
                activity: activityArg,
                begin: beginArg,
                end: endArg,
                description: descArg,
                tags: tagsArg)
            isSaving = false
            if ok {
                onSaved()
            } else {
                errorMessage = String(localized: "Kimai rejected the edit. The activity may not belong to that project.")
            }
        }
    }
}
