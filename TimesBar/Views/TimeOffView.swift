import SwiftUI

struct TimeOffView: View {
    @EnvironmentObject var store: TimerStore
    let onClose: () -> Void

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
            Divider()
            budgetEditor
        }
        .onAppear { Task { await store.refreshAbsences() } }
    }

    // MARK: - Sections

    private var vacationCard: some View {
        let used = store.vacationUsedDays
        let total = max(Double(store.vacationTotalAvailable), 0.0001)
        let progress = min(used / total, 1.0)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Urlaub")
                Spacer()
                HStack(spacing: 0) {
                    Text(formatDays(used))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text(" / \(store.vacationTotalAvailable) days")
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
            HStack(spacing: 6) {
                Text("\(formatDays(store.vacationRemainingDays)) days remaining")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if store.vacationYearsAccrued > 1 {
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("\(store.vacationYearsAccrued) yrs × \(store.vacationBudgetDays) since \(store.vacationTrackingStartYear)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var upcomingList: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(text: "Upcoming")
            if store.upcomingAbsences.isEmpty {
                Text("Nothing scheduled.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                VStack(spacing: 4) {
                    ForEach(store.upcomingAbsences.prefix(4)) { absence in
                        absenceRow(absence)
                    }
                }
            }
        }
    }

    private func absenceRow(_ absence: Absence) -> some View {
        HStack(spacing: 10) {
            Text(formatDate(absence.date))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(color(for: absence.type))
                    .frame(width: 6, height: 6)
                Text(typeLabel(absence.type))
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(absence.halfDay ? "½ day" : "1 day")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var budgetEditor: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        return VStack(alignment: .leading, spacing: 6) {
            SectionHeader(text: "Budget")
            Text("Kimai's API doesn't expose your contract, so set these once. TimesBar then fetches every approved holiday from Jan 1 of \"Since\" onwards.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            stepperRow(
                label: "Annual",
                value: Binding(
                    get: { store.vacationBudgetDays },
                    set: { store.vacationBudgetDays = $0 }
                ),
                range: 0...60,
                suffix: "days"
            )
            stepperRow(
                label: "Since",
                value: Binding(
                    get: { store.vacationTrackingStartYear },
                    set: { store.vacationTrackingStartYear = $0 }
                ),
                range: 2010...currentYear,
                suffix: nil
            )
        }
    }

    private func stepperRow(label: String,
                             value: Binding<Int>,
                             range: ClosedRange<Int>,
                             suffix: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Spacer()
            Stepper(value: value, in: range) {
                Text(suffix.map { "\(value.wrappedValue) \($0)" } ?? "\(value.wrappedValue)")
                    .font(.system(size: 11, design: .monospaced))
            }
            .controlSize(.mini)
        }
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
        case "freecompensation", "free_compensation": return "Freizeitausgleich"
        case "other": return "Andere"
        case "parental": return "Elternzeit"
        default: return type.prefix(1).uppercased() + type.dropFirst()
        }
    }

    private func color(for type: String) -> Color {
        switch type.lowercased() {
        case "holiday": return .kimaiGreen
        case "sick", "sickness": return Color(red: 0.85, green: 0.55, blue: 0.2)
        case "freecompensation", "free_compensation": return Color(red: 0.3, green: 0.55, blue: 0.95)
        default: return Color.secondary
        }
    }
}
