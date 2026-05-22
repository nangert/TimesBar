import SwiftUI

/// Pill-triggered date field that expands a custom inline `CalendarGrid` below
/// itself. Shared by TimeOffView, StartTimerForm, and EditActiveTimerForm —
/// we don't use SwiftUI's `.compact` (tiny popover) or `.graphical` (cramped
/// day cells), both of which are awkward to hit with a mouse.
struct DateFieldRow: View {
    let label: String
    @Binding var date: Date
    let minDate: Date?
    let maxDate: Date?
    @Binding var isExpanded: Bool

    init(label: String,
         date: Binding<Date>,
         minDate: Date? = nil,
         maxDate: Date? = nil,
         isExpanded: Binding<Bool>) {
        self.label = label
        self._date = date
        self.minDate = minDate
        self.maxDate = maxDate
        self._isExpanded = isExpanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FormRow(label: label) {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 4)
                        Image(systemName: isExpanded ? "calendar.badge.checkmark" : "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .pillFieldStyle()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if isExpanded {
                CalendarGrid(date: $date, minDate: minDate, maxDate: maxDate)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Custom calendar grid with 30pt-tall day cells, Monday-first weeks, and
/// keyboard-month navigation via chevrons. Chosen over the SwiftUI built-ins
/// because their day cells (~20-24pt) are too small to click reliably.
struct CalendarGrid: View {
    @Binding var date: Date
    let minDate: Date?
    let maxDate: Date?

    @State private var anchor: Date

    init(date: Binding<Date>, minDate: Date?, maxDate: Date? = nil) {
        self._date = date
        self.minDate = minDate
        self.maxDate = maxDate
        let cal = Self.calendar
        let comps = cal.dateComponents([.year, .month], from: date.wrappedValue)
        self._anchor = State(initialValue: cal.date(from: comps) ?? date.wrappedValue)
    }

    private static var calendar: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }
    private var cal: Calendar { Self.calendar }

    var body: some View {
        VStack(spacing: 6) {
            header
            weekdayLabels
            daysGrid
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var header: some View {
        HStack {
            chevron(systemName: "chevron.left") { stepMonth(-1) }
            Spacer()
            Text(monthYearTitle)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            chevron(systemName: "chevron.right") { stepMonth(1) }
        }
    }

    private func chevron(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var monthYearTitle: String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f.string(from: anchor)
    }

    private func stepMonth(_ delta: Int) {
        if let next = cal.date(byAdding: .month, value: delta, to: anchor) {
            anchor = next
        }
    }

    private var weekdayLabels: some View {
        HStack(spacing: 4) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private struct GridCell {
        let date: Date
        let day: Int
        let isInCurrentMonth: Bool
    }

    private var cells: [GridCell] {
        let firstWeekday = cal.component(.weekday, from: anchor)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let firstCellDate = cal.date(byAdding: .day, value: -leading, to: anchor) ?? anchor
        let monthRange = cal.range(of: .day, in: .month, for: anchor) ?? 0..<30
        let daysInMonth = monthRange.count

        return (0..<42).map { idx in
            let cellDate = cal.date(byAdding: .day, value: idx, to: firstCellDate) ?? firstCellDate
            let dayNumber = cal.component(.day, from: cellDate)
            let offsetFromMonthStart = idx - leading
            let inCurrentMonth = offsetFromMonthStart >= 0 && offsetFromMonthStart < daysInMonth
            return GridCell(date: cellDate, day: dayNumber, isInCurrentMonth: inCurrentMonth)
        }
    }

    private var rowCount: Int {
        let allCells = cells
        var rows = 6
        while rows > 4 {
            let rowStart = (rows - 1) * 7
            let isEmpty = (rowStart..<rowStart+7).allSatisfy { !allCells[$0].isInCurrentMonth }
            if isEmpty { rows -= 1 } else { break }
        }
        return rows
    }

    private var daysGrid: some View {
        let allCells = cells
        let rows = rowCount
        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { col in
                        let cell = allCells[row * 7 + col]
                        CalendarDayCell(
                            day: cell.day,
                            isInCurrentMonth: cell.isInCurrentMonth,
                            isSelected: cal.isDate(cell.date, inSameDayAs: date),
                            isToday: cal.isDateInToday(cell.date),
                            isEnabled: isEnabled(cell.date),
                            onTap: {
                                // Preserve the time-of-day from the previous
                                // selection so the time picker keeps its value
                                // when the user picks a different day.
                                let comps = cal.dateComponents([.hour, .minute, .second], from: date)
                                if let merged = cal.date(bySettingHour: comps.hour ?? 0,
                                                          minute: comps.minute ?? 0,
                                                          second: comps.second ?? 0,
                                                          of: cell.date) {
                                    date = merged
                                } else {
                                    date = cell.date
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func isEnabled(_ d: Date) -> Bool {
        let day = cal.startOfDay(for: d)
        if let minDate, day < cal.startOfDay(for: minDate) { return false }
        if let maxDate, day > cal.startOfDay(for: maxDate) { return false }
        return true
    }
}

struct CalendarDayCell: View {
    let day: Int
    let isInCurrentMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    @State private var hover = false

    var body: some View {
        Button(action: onTap) {
            Text("\(day)")
                .font(.system(size: 12,
                              weight: isSelected || isToday ? .semibold : .regular,
                              design: .default))
                .frame(maxWidth: .infinity, minHeight: 30)
                .foregroundStyle(textColor)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hover = isEnabled && $0 }
    }

    private var textColor: Color {
        if !isEnabled { return .secondary.opacity(0.35) }
        if !isInCurrentMonth { return .secondary.opacity(0.55) }
        if isSelected { return .white }
        return .primary
    }

    @ViewBuilder
    private var background: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.kimaiGreen)
        } else if hover {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.1))
        } else if isToday {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kimaiGreen.opacity(0.6), lineWidth: 1)
        }
    }
}
