import SwiftUI

struct WeekBarChart: View {
    let weekHours: [Double]
    let todayIndex: Int

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let maxValue = max(weekHours.max() ?? 0, 0.0001)
        VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(weekHours.enumerated()), id: \.offset) { idx, value in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: idx))
                            .frame(height: max(3, geo.size.height * CGFloat(value / maxValue)))
                    }
                }
            }
            .frame(height: 28)
            HStack(spacing: 4) {
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                    Text(label)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(idx == todayIndex ? Color.primary : Color.secondary.opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index == todayIndex { return .kimaiGreen }
        if index >= 5 { return .secondary.opacity(0.2) }   // Sat/Sun
        return .secondary.opacity(0.55)
    }
}
