import SwiftUI

struct StartTimerForm: View {
    @EnvironmentObject var store: TimerStore
    let onCancel: () -> Void
    let onStarted: () -> Void

    @State private var projectId: Int?
    @State private var activityId: Int?
    @State private var description: String = ""
    @State private var tags: [String] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    /// "Log past entry" toggle. When on, the form expands to collect a custom
    /// begin (and optional end) instead of starting from "now".
    @State private var isPastEntry: Bool = false
    @State private var begin: Date = Self.defaultBegin()
    @State private var end: Date = Date()
    @State private var hasEnd: Bool = true
    @State private var calendarExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelHeader(title: isPastEntry ? "Log entry" : "New timer",
                        onClose: onCancel)

            Toggle(isOn: $isPastEntry.animation(.easeInOut(duration: 0.15))) {
                Text("Log past entry")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

            if isPastEntry && !suggestionItems.isEmpty {
                SuggestionsList(items: suggestionItems, onPick: prefill)
                Divider()
            }

            TimesheetFieldsSection(
                projectId: $projectId,
                activityId: $activityId,
                description: $description,
                tags: $tags
            )

            if isPastEntry {
                Divider()

                DateFieldRow(
                    label: "Date",
                    date: $begin,
                    isExpanded: $calendarExpanded
                )
                .onChange(of: begin) { _, newBegin in
                    // Keep end on the same day as begin so the TimeRangeBar
                    // shows both inside its window.
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

                Toggle(isOn: $hasEnd.animation(.easeInOut(duration: 0.15))) {
                    Text("Set end time")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                VStack(alignment: .leading, spacing: 8) {
                    TimeRangeBar(
                        day: begin,
                        mode: hasEnd ? .range : .beginOnly,
                        begin: $begin,
                        end: $end,
                        existingEntries: store.nearbyEntries,
                        colorForProject: { store.projectColor(for: $0) }
                    )

                    HStack(spacing: 16) {
                        TimeNudgeField(label: "Begin", date: $begin)
                        if hasEnd {
                            TimeNudgeField(label: "End", date: $end, minDate: begin.addingTimeInterval(60))
                        }
                        Spacer()
                        if hasEnd {
                            Text(durationString)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(footnote)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(action: submit) {
                    Label(submitLabel, systemImage: submitIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .disabled(!canSubmit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if isPastEntry {
                Task { await store.refreshNearbyEntries(around: begin) }
            }
        }
        .onChange(of: isPastEntry) { _, newValue in
            if newValue {
                Task { await store.refreshNearbyEntries(around: begin) }
            } else {
                store.clearNearbyEntries()
            }
        }
        .onChange(of: Calendar.current.startOfDay(for: begin)) { _, _ in
            if isPastEntry {
                Task { await store.refreshNearbyEntries(around: begin) }
            }
        }
        .onDisappear {
            store.clearNearbyEntries()
        }
    }

    // MARK: - Computed

    private var suggestionItems: [QuickStartItem] {
        store.recent
            .filter { $0.end != nil }
            .prefix(5)
            .map { entry in
                QuickStartItem(
                    id: entry.id,
                    projectId: entry.project,
                    activityId: entry.activity,
                    description: entry.description,
                    title: store.projectTitle(for: entry.project),
                    durationSeconds: (entry.end ?? Date()).timeIntervalSince(entry.begin),
                    tags: entry.tags
                )
            }
    }

    private var canSubmit: Bool {
        guard projectId != nil, activityId != nil, !isSubmitting else { return false }
        if isPastEntry && hasEnd && end <= begin { return false }
        return true
    }

    private var submitLabel: String {
        if isSubmitting { return "Saving…" }
        if isPastEntry && hasEnd { return "Log" }
        if isPastEntry { return "Start (backdated)" }
        return "Start"
    }

    private var submitIcon: String {
        isPastEntry && hasEnd ? "checkmark" : "play.fill"
    }

    private var durationString: String {
        let seconds = max(0, end.timeIntervalSince(begin))
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private var footnote: String {
        if hasEnd {
            return "Adds a completed entry. Drag the green band to move both ends; drag a handle to resize."
        }
        return "Starts a running timer backdated to the chosen begin time. Drag the handle to set begin."
    }

    private static func defaultBegin() -> Date {
        let now = Date()
        let snap: TimeInterval = 300
        let snapped = (now.addingTimeInterval(-3600).timeIntervalSince1970 / snap).rounded() * snap
        return Date(timeIntervalSince1970: snapped)
    }

    // MARK: - Actions

    private func prefill(_ item: QuickStartItem) {
        projectId = item.projectId
        activityId = item.activityId
        if let desc = item.description, !desc.isEmpty {
            description = desc
        }
        tags = item.tags
    }

    private func submit() {
        guard let p = projectId, let a = activityId else { return }
        isSubmitting = true
        errorMessage = nil
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = trimmed.isEmpty ? nil : trimmed
        let tagsArg: [String]? = tags.isEmpty ? nil : tags
        Task {
            let ok: Bool
            if isPastEntry {
                ok = await store.logEntry(
                    project: p,
                    activity: a,
                    begin: begin,
                    end: hasEnd ? end : nil,
                    description: note,
                    tags: tagsArg)
            } else {
                ok = await store.startCheckingResult(
                    project: p,
                    activity: a,
                    description: note,
                    tags: tagsArg)
            }
            isSubmitting = false
            if ok {
                onStarted()
            } else {
                errorMessage = "Kimai rejected the request. The activity may not belong to that project."
            }
        }
    }
}

/// Recent project/activity combos shown above the past-entry form. Clicking
/// a row prefills project/activity/description; it does NOT submit the form.
/// Visually mirrors `QuickStartSection` but with a distinct icon to signal
/// "fill" vs the existing "restart" action.
private struct SuggestionsList: View {
    let items: [QuickStartItem]
    let onPick: (QuickStartItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(text: "Recent")
            VStack(spacing: 2) {
                ForEach(items) { item in
                    SuggestionRow(item: item) { onPick(item) }
                }
            }
        }
    }
}

private struct SuggestionRow: View {
    let item: QuickStartItem
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    if let desc = item.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !item.tags.isEmpty {
                        TagChipsRow(tags: item.tags)
                    }
                }
                Spacer(minLength: 8)
                Text(formatHoursAndMinutes(seconds: item.durationSeconds))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(hover ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
