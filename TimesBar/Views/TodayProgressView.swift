import SwiftUI

struct TodayProgressView: View {
    let hoursToday: Double
    let targetHours: Double

    private var remainingHours: Double { targetHours - hoursToday }
    private var isOver: Bool { hoursToday >= targetHours }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Today")
                Spacer()
                HStack(spacing: 0) {
                    Text("\(formatHoursAndMinutes(hoursToday)) today")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text(isOver
                         ? " · \(formatHoursAndMinutes(hoursToday - targetHours)) over target"
                         : " · \(formatHoursAndMinutes(remainingHours)) to target")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            ThinProgressBar(progress: hoursToday / targetHours,
                            showsOverState: true)
        }
    }
}
