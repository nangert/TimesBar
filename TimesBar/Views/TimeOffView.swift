import SwiftUI

struct TimeOffView: View {
    @EnvironmentObject var store: TimerStore
    let onClose: () -> Void

    /// Request-form state. Lives on the view so it resets every time the
    /// panel is closed and re-opened — the form is meant to be ephemeral.
    @State private var showingRequestForm: Bool = false
    @State private var requestDate: Date = Date()
    @State private var requestEndDate: Date = Date()
    @State private var requestMultiDay: Bool = false
    @State private var requestType: String = "holiday"
    @State private var requestHalfDay: Bool = false
    @State private var requestComment: String = ""
    @State private var requestSubmitting: Bool = false
    @State private var requestError: String?

    /// Which date field (if any) has the graphical calendar expanded. Only
    /// one can be expanded at a time — opening one auto-closes the other.
    private enum ExpandedDateField { case from, to }
    @State private var expandedDateField: ExpandedDateField?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(text: "Time off")
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(2)
                }
                .buttonStyle(.plain)
            }

            vacationCard
            Divider()
            upcomingList
            if showingRequestForm {
                Divider()
                requestForm
            }
            Divider()
            budgetEditor
        }
        .onAppear { Task { await store.refreshAbsences() } }
    }

    // MARK: - Sections

    private var vacationCard: some View {
        let used = store.vacationUsedDays
        let total = max(store.vacationTotalAvailable, 0.0001)
        let progress = min(used / total, 1.0)
        let breakdown = store.vacationBreakdown
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Urlaub")
                Spacer()
                HStack(spacing: 0) {
                    Text(formatDays(used))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text(" / \(formatDays(store.vacationTotalAvailable)) days")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.18))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.kimaiGreen)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
            Text("\(formatDays(store.vacationRemainingDays)) days remaining")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            if breakdown.count > 1 {
                yearBreakdown(breakdown)
            }
        }
    }

    private func yearBreakdown(_ stats: [TimerStore.VacationYearStats]) -> some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        let annual = Double(store.vacationBudgetDays)
        return VStack(spacing: 2) {
            ForEach(stats, id: \.year) { s in
                HStack(spacing: 6) {
                    Text(String(s.year))
                        .font(.system(size: 11, weight: s.year == currentYear ? .medium : .regular,
                                       design: .monospaced))
                        .foregroundStyle(s.year == currentYear ? Color.primary : .secondary)
                        .frame(width: 38, alignment: .leading)
                    HStack(spacing: 0) {
                        Text(formatDays(s.used))
                            .font(.system(size: 11, design: .monospaced))
                        Text(" / \(formatDays(s.available))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if s.available > 0 && s.available < annual {
                        Text("prorated")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.12))
                            )
                    }
                    Spacer()
                }
            }
        }
        .padding(.top, 4)
    }

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Upcoming")
                Spacer()
                Button {
                    if showingRequestForm {
                        showingRequestForm = false
                    } else {
                        // Reset to sensible defaults each time the form opens.
                        requestDate = Date()
                        requestEndDate = Date()
                        requestMultiDay = false
                        requestType = "holiday"
                        requestHalfDay = false
                        requestComment = ""
                        requestError = nil
                        expandedDateField = nil
                        showingRequestForm = true
                    }
                } label: {
                    Image(systemName: showingRequestForm ? "minus" : "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help(showingRequestForm ? "Cancel" : "Request time off")
            }
            if store.upcomingAbsences.isEmpty {
                Text("Nothing scheduled.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                VStack(spacing: 4) {
                    ForEach(store.upcomingAbsences.prefix(4)) { absence in
                        AbsenceRow(
                            absence: absence,
                            dateText: formatDate(absence.date),
                            typeText: typeLabel(absence.type),
                            tint: color(for: absence.type),
                            onCancel: {
                                Task { _ = await store.cancelAbsence(id: absence.id) }
                            }
                        )
                    }
                }
            }
        }
    }

    private var requestForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "Request time off")
                // Keep `to` from drifting before `from` when the user picks a
                // later From date after enabling Multi-day.
                .onChange(of: requestDate) { _, newFrom in
                    if requestMultiDay && requestEndDate < newFrom {
                        requestEndDate = newFrom
                    }
                }

            FormRow(label: "Type") {
                Menu {
                    Button("Urlaub") { requestType = "holiday" }
                    Button("Zeitausgleich") { requestType = "time_off" }
                    Button("Krankheit") { requestType = "sickness" }
                    Button("Elternzeit") { requestType = "parental" }
                    Button("Unbezahlter Urlaub") { requestType = "unpaid_vacation" }
                    Button("Sonstiges") { requestType = "other" }
                } label: {
                    HStack {
                        Text(typeLabel(requestType))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 12))
                    .pillFieldStyle()
                    .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize(horizontal: false, vertical: true)
            }

            DateFieldRow(
                label: "From",
                date: $requestDate,
                minDate: nil,
                isExpanded: Binding(
                    get: { expandedDateField == .from },
                    set: { isOn in
                        expandedDateField = isOn ? .from
                            : (expandedDateField == .from ? nil : expandedDateField)
                    }
                )
            )

            FormRow(label: "Multi-day") {
                Toggle("", isOn: $requestMultiDay)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .onChange(of: requestMultiDay) { _, isOn in
                        if isOn {
                            // Half-day is meaningless across a range.
                            requestHalfDay = false
                            // Seed end with `from` if it's still earlier than the start.
                            if requestEndDate < requestDate { requestEndDate = requestDate }
                        } else {
                            // Collapse the To field if it was open.
                            if expandedDateField == .to { expandedDateField = nil }
                        }
                    }
            }

            if requestMultiDay {
                DateFieldRow(
                    label: "To",
                    date: $requestEndDate,
                    minDate: requestDate,
                    isExpanded: Binding(
                        get: { expandedDateField == .to },
                        set: { isOn in
                            expandedDateField = isOn ? .to
                                : (expandedDateField == .to ? nil : expandedDateField)
                        }
                    )
                )
            } else {
                FormRow(label: "Half day") {
                    Toggle("", isOn: $requestHalfDay)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
            }

            FormRow(label: "Note") {
                TextField("Optional", text: $requestComment)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .pillFieldStyle()
            }

            if let requestError {
                Text(requestError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button {
                    showingRequestForm = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button {
                    submitRequest()
                } label: {
                    Label(requestSubmitting ? "Submitting…" : "Submit",
                          systemImage: "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .disabled(requestSubmitting || store.userMe == nil)
            }
        }
    }

    private func submitRequest() {
        guard !requestSubmitting else { return }
        requestSubmitting = true
        requestError = nil
        let trimmed = requestComment.trimmingCharacters(in: .whitespacesAndNewlines)
        let endDate: Date? = requestMultiDay ? requestEndDate : nil
        let date = requestDate
        let type = requestType
        let halfDay = requestHalfDay
        Task {
            let ok = await store.requestAbsence(
                date: date,
                end: endDate,
                type: type,
                halfDay: halfDay,
                comment: trimmed.isEmpty ? nil : trimmed)
            requestSubmitting = false
            if ok {
                showingRequestForm = false
            } else {
                requestError = "Kimai rejected the request. Check the date and try again."
            }
        }
    }

    private var budgetEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(store.vacationBudgetDays) days/year · from your Kimai profile")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Text(detectedFootnote)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var detectedFootnote: String {
        if let start = store.contractStartDate {
            let f = DateFormatter()
            f.dateFormat = "d MMM yyyy"
            f.locale = Locale(identifier: "en_US_POSIX")
            return "Contract started \(f.string(from: start)) (from your Kimai profile)."
        }
        if let detected = store.detectedFirstTimesheetYear {
            return "Counting from \(detected), your earliest timesheet."
        }
        return "Counting from the current year. Log timesheets across multiple years and TimesBar picks the earliest one up."
    }

    // MARK: - Helpers

    private func formatDays(_ days: Double) -> String {
        let rounded = (days * 2).rounded() / 2
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: date)
    }

    private func typeLabel(_ type: String) -> String {
        switch type.lowercased() {
        case "holiday": return "Urlaub"
        case "sick", "sickness": return "Krankheit"
        case "freecompensation", "free_compensation", "time_off": return "Zeitausgleich"
        case "other": return "Sonstiges"
        case "parental": return "Elternzeit"
        case "sickness_child": return "Krankheit (Kind)"
        case "unpaid_vacation": return "Unbezahlter Urlaub"
        default: return type.prefix(1).uppercased() + type.dropFirst()
        }
    }

    private func color(for type: String) -> Color {
        switch type.lowercased() {
        case "holiday": return .kimaiGreen
        case "sick", "sickness", "sickness_child": return Color(red: 0.85, green: 0.55, blue: 0.2)
        case "freecompensation", "free_compensation", "time_off": return Color(red: 0.3, green: 0.55, blue: 0.95)
        default: return Color.secondary
        }
    }
}

/// One Upcoming row. Extracted into its own view so each row can carry
/// `@State hover` for the reveal-on-hover cancel button without re-rendering
/// the entire list on mouse movement.
private struct AbsenceRow: View {
    let absence: Absence
    let dateText: String
    let typeText: String
    let tint: Color
    let onCancel: () -> Void

    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Text(dateText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(typeText)
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(absence.halfDay ? "½ day" : "1 day")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
            if hover {
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel this absence")
                .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }
}
