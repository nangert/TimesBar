import SwiftUI

struct TotalsSection: View {
    let weekHours: [Double]

    private var todayHours: Double {
        let cal = Calendar(identifier: .iso8601)
        let weekday = cal.component(.weekday, from: Date())
        // ISO calendar: Monday = 2, Sunday = 1. Map to 0...6 with Monday = 0.
        let index = (weekday + 5) % 7
        return weekHours[safe: index] ?? 0
    }

    private var weekTotal: Double { weekHours.reduce(0, +) }

    var body: some View {
        HStack(spacing: 16) {
            stat(label: "Today", value: todayHours)
            stat(label: "This week", value: weekTotal)
            Spacer()
            Sparkline(values: weekHours)
                .frame(width: 80, height: 24)
        }
    }

    private func stat(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(format(value)).font(.system(.body, design: .monospaced))
        }
    }

    private func format(_ hours: Double) -> String {
        let total = Int(hours * 3600)
        return String(format: "%02d:%02d", total / 3600, (total % 3600) / 60)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
