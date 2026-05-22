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
            GeometryReader { geo in
                let progress = min(max(hoursToday / targetHours, 0), 1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.18))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.kimaiGreen)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)
        }
    }
}
