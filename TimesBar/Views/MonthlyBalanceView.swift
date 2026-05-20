import SwiftUI

struct MonthlyBalanceView: View {
    @EnvironmentObject var store: TimerStore
    let onClose: () -> Void

    @State private var year: Int = Calendar.current.component(.year, from: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .onAppear { Task { await store.loadYearlyData(year) } }
        .onChange(of: year) { _, newYear in
            Task { await store.loadYearlyData(newYear) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader(text: "Monthly balance")
            Spacer()
            yearStepper
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(2)
            }
            .buttonStyle(.plain)
        }
    }

    private var yearStepper: some View {
        HStack(spacing: 4) {
            Button {
                year -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(year <= 2010)

            Text("\(String(year))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(width: 40, alignment: .center)

            Button {
                year += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(year >= Calendar.current.component(.year, from: Date()))
        }
    }

    // MARK: - Body content

    @ViewBuilder private var content: some View {
        if store.loadingYear == year || store.yearlyData?.year != year {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Loading…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 18)
        } else if let data = store.yearlyData {
            let months = MonthlyBalanceCalculator.months(for: year, timesheets: data.timesheets)
            if months.isEmpty {
                Text("No time entries logged for \(String(year)).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                let stats = months.map { month in
                    MonthlyBalanceCalculator.stats(
                        year: year,
                        month: month,
                        hoursPerWorkingDay: store.hoursPerWorkingDay,
                        timesheets: data.timesheets,
                        absences: data.absences,
                        publicHolidays: data.publicHolidays
                    )
                }
                monthsList(stats)
                Divider()
                yearTotalRow(stats: stats)
                hoursPerWeekInfo
            }
        }
    }

    private func monthsList(_ stats: [MonthlyStats]) -> some View {
        VStack(spacing: 4) {
            ForEach(stats, id: \.month) { s in
                monthRow(s)
            }
        }
    }

    private func monthRow(_ s: MonthlyStats) -> some View {
        HStack(spacing: 8) {
            Text(monthName(s.month))
                .font(.system(size: 12, weight: .medium))
                .frame(width: 38, alignment: .leading)
            HStack(spacing: 0) {
                Text(formatH(s.actualHours))
                    .font(.system(size: 12, design: .monospaced))
                Text(" / ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(formatH(s.expectedHours))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            balanceChip(s.balanceHours, isCurrentMonth: isCurrentMonth(s.month))
        }
        .padding(.vertical, 2)
    }

    private func yearTotalRow(stats: [MonthlyStats]) -> some View {
        let totalActual = stats.reduce(0.0) { $0 + $1.actualHours }
        let totalExpected = stats.reduce(0.0) { $0 + $1.expectedHours }
        let totalBalance = totalActual - totalExpected
        return HStack(spacing: 8) {
            Text("Year")
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .tracking(1.0)
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .leading)
            HStack(spacing: 0) {
                Text(formatH(totalActual))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                Text(" / ")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(formatH(totalExpected))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            balanceChip(totalBalance, isCurrentMonth: false)
        }
        .padding(.vertical, 2)
    }

    private var hoursPerWeekInfo: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text("\(formatHoursPerWeek(store.hoursPerWeek)) per week · from your Kimai profile")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func formatHoursPerWeek(_ hours: Double) -> String {
        hours.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(hours)) h"
            : String(format: "%.1f h", hours)
    }

    private func balanceChip(_ balance: Double, isCurrentMonth: Bool) -> some View {
        let positive = balance >= 0
        let color: Color = positive ? .kimaiGreen : .kimaiStopTint
        let sign = positive ? "+" : "−"
        let magnitude = abs(balance)
        return HStack(spacing: 4) {
            Image(systemName: positive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text("\(sign)\(formatH(magnitude))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.14))
        )
        .opacity(isCurrentMonth ? 0.85 : 1.0)
    }

    // MARK: - Helpers

    private func monthName(_ month: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.shortMonthSymbols[month - 1]
    }

    private func formatH(_ hours: Double) -> String {
        let total = Int(hours.rounded())
        return "\(total)h"
    }

    private func isCurrentMonth(_ month: Int) -> Bool {
        let cal = Calendar.current
        let now = Date()
        return year == cal.component(.year, from: now) && month == cal.component(.month, from: now)
    }
}
