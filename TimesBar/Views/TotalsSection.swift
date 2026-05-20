import SwiftUI

struct TotalsSection: View {
    let weekHours: [Double]
    let dailyTargetHours: Double

    private var todayIndex: Int {
        let cal = Calendar(identifier: .iso8601)
        let weekday = cal.component(.weekday, from: Date())
        // ISO weekday: Sunday = 1 ... Saturday = 7. Map so Monday = 0.
        return (weekday + 5) % 7
    }

    private var hoursToday: Double { weekHours[safe: todayIndex] ?? 0 }
    private var weekTotal: Double { weekHours.reduce(0, +) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TodayProgressView(hoursToday: hoursToday, targetHours: dailyTargetHours)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    SectionHeader(text: "This week")
                    Spacer()
                    Text(formatHoursAndMinutes(weekTotal))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                WeekBarChart(weekHours: weekHours, todayIndex: todayIndex)
            }
        }
    }
}
