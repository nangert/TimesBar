import SwiftUI

struct WeekBarChart: View {
    let weekHours: [Double]
    let todayIndex: Int
    /// Per-day project breakdown. Same length as `weekHours` (7 elements).
    /// Each element is a list of `(projectId, hours)` pairs sorted descending.
    var weekProjectHours: [[(projectId: Int, hours: Double)]] = Array(repeating: [], count: 7)
    /// Resolves a project ID to its display color.
    var colorForProject: (Int) -> Color = { id in Color.forProject(id: id, hex: nil) }

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        let maxValue = max(weekHours.max() ?? 0, 0.0001)
        VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(weekHours.enumerated()), id: \.offset) { idx, value in
                        let barHeight = max(3, geo.size.height * CGFloat(value / maxValue))
                        let segments = weekProjectHours[safe: idx] ?? []
                        if segments.isEmpty || idx >= 5 {
                            // Weekends or no breakdown available: solid fallback color.
                            RoundedRectangle(cornerRadius: 2)
                                .fill(fallbackColor(for: idx))
                                .frame(height: barHeight)
                        } else {
                            // Stacked segments, bottom-to-top (last segment on top visually
                            // because we align .bottom in the HStack).
                            GeometryReader { barGeo in
                                VStack(spacing: 0) {
                                    ForEach(Array(segments.enumerated()), id: \.offset) { segIdx, seg in
                                        let segFrac = CGFloat(seg.hours / value)
                                        let segHeight = max(1, barGeo.size.height * segFrac)
                                        Rectangle()
                                            .fill(colorForProject(seg.projectId))
                                            .frame(height: segHeight)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 2))
                            }
                            .frame(height: barHeight)
                        }
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

    private func fallbackColor(for index: Int) -> Color {
        if index == todayIndex { return .kimaiGreen }
        if index >= 5 { return .secondary.opacity(0.2) }
        return .secondary.opacity(0.55)
    }
}
