import SwiftUI

struct TodayProgressView: View {
    let hoursToday: Double
    let targetHours: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Today")
                Spacer()
                HStack(spacing: 0) {
                    Text(formatHoursAndMinutes(hoursToday))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Text(" / \(formatHoursAndMinutes(targetHours))")
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
