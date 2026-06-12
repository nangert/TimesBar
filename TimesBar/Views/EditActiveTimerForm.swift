import SwiftUI

/// Edit the currently running timer in place. PATCHes /api/timesheets/{id},
/// so changing project/activity does NOT restart the entry — the same row is
/// updated and the elapsed counter keeps ticking against the (possibly new)
/// begin time.
struct EditActiveTimerForm: View {
    @EnvironmentObject var store: TimerStore
    let onCancel: () -> Void
    let onSaved: () -> Void

    /// `draft.end` doubles as the dummy binding for TimeRangeBar's `end`
    /// parameter in `.beginOnly` mode — the bar never writes it there, and
    /// the save path never sends it.
    @State private var draft = TimesheetDraft()
    @State private var initial = TimesheetDraft()
    @State private var isSaving = false
    @State private var errorMessage: String?

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

            TimesheetFieldsSection(
                projectId: $draft.projectId,
                activityId: $draft.activityId,
                description: $draft.description,
                tags: $draft.tags
            )

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                TimeRangeBar(
                    day: draft.begin,
                    mode: .beginOnly,
                    begin: $draft.begin,
                    end: $draft.end,
                    existingEntries: store.nearbyEntries,
                    excludeEntryId: store.active?.id,
                    colorForProject: { store.projectColor(for: $0) }
                )

                HStack(spacing: 16) {
                    TimeNudgeField(
                        label: "Begin",
                        date: $draft.begin,
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
            Task { await store.refreshNearbyEntries(around: draft.begin) }
        }
        .onDisappear {
            store.clearNearbyEntries()
        }
    }

    private func hydrate() {
        guard let active = store.active else { return }
        draft = TimesheetDraft(entry: active)
        initial = draft
    }

    private var elapsedString: String {
        let secs = max(0, Int(Date().timeIntervalSince(draft.begin)))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return String(format: "%dh %02dm elapsed", h, m)
    }

    private var hint: String {
        let args = draft.patchArgs(from: initial)
        let beginChanged = args.begin != nil
        let categoryChanged = args.project != nil || args.activity != nil
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
        guard !isSaving, draft.projectId != nil, draft.activityId != nil else { return false }
        return draft.differs(from: initial)
    }

    private func save() {
        guard draft.projectId != nil, draft.activityId != nil else { return }
        isSaving = true
        errorMessage = nil
        // patchArgs sends tags only when they changed, passing the (possibly
        // empty) array so the user can clear tags intentionally. `end` is
        // never sent — updateActiveTimer doesn't accept one.
        let args = draft.patchArgs(from: initial)

        Task {
            let ok = await store.updateActiveTimer(
                begin: args.begin,
                project: args.project,
                activity: args.activity,
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
