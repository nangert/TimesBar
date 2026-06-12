import SwiftUI

/// Edit any completed timesheet entry (not just the running one). PATCHes
/// /api/timesheets/{id} with the changed fields. Both begin and end are
/// draggable because past entries always have a finite time range.
struct EditTimesheetForm: View {
    @EnvironmentObject var store: TimerStore
    let entry: TimesheetEntity
    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var draft = TimesheetDraft()
    @State private var initial = TimesheetDraft()
    @State private var calendarExpanded: Bool = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelHeader(title: "Edit entry", onClose: onCancel)

            TimesheetFieldsSection(
                projectId: $draft.projectId,
                activityId: $draft.activityId,
                description: $draft.description,
                tags: $draft.tags
            )

            Divider()

            DateFieldRow(
                label: "Date",
                date: $draft.begin,
                isExpanded: $calendarExpanded
            )
            .onChange(of: draft.begin) { _, newBegin in
                // Keep end on the same calendar day when the user picks a
                // different date, and ensure end stays after begin.
                let cal = Calendar.current
                if !cal.isDate(draft.end, inSameDayAs: newBegin) {
                    let comps = cal.dateComponents([.hour, .minute, .second], from: draft.end)
                    if let migrated = cal.date(bySettingHour: comps.hour ?? 0,
                                                minute: comps.minute ?? 0,
                                                second: comps.second ?? 0,
                                                of: newBegin) {
                        draft.end = migrated
                    }
                }
                if draft.end <= newBegin {
                    draft.end = newBegin.addingTimeInterval(3600)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TimeRangeBar(
                    day: draft.begin,
                    mode: .range,
                    begin: $draft.begin,
                    end: $draft.end,
                    existingEntries: store.nearbyEntries,
                    excludeEntryId: entry.id,
                    colorForProject: { store.projectColor(for: $0) }
                )

                HStack(spacing: 16) {
                    TimeNudgeField(label: "Begin", date: $draft.begin)
                    TimeNudgeField(label: "End", date: $draft.end, minDate: draft.begin.addingTimeInterval(60))
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
            Task { await store.refreshNearbyEntries(around: draft.begin) }
        }
        .onChange(of: Calendar.current.startOfDay(for: draft.begin)) { _, _ in
            Task { await store.refreshNearbyEntries(around: draft.begin) }
        }
        .onDisappear {
            store.clearNearbyEntries()
        }
    }

    // MARK: - Helpers

    private func hydrate() {
        draft = TimesheetDraft(entry: entry)
        initial = draft
    }

    private var durationString: String {
        let seconds = max(0, draft.end.timeIntervalSince(draft.begin))
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private var canSave: Bool {
        guard !isSaving, draft.projectId != nil, draft.activityId != nil else { return false }
        guard draft.end > draft.begin else { return false }
        return draft.differs(from: initial)
    }

    private func save() {
        guard draft.projectId != nil, draft.activityId != nil else { return }
        isSaving = true
        errorMessage = nil
        let args = draft.patchArgs(from: initial)

        Task {
            let ok = await store.updateTimesheet(
                id: entry.id,
                project: args.project,
                activity: args.activity,
                begin: args.begin,
                end: args.end,
                description: args.description,
                tags: args.tags)
            isSaving = false
            if ok {
                onSaved()
            } else {
                errorMessage = "Kimai rejected the edit. The activity may not belong to that project."
            }
        }
    }
}
