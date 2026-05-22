import SwiftUI

struct SleepReconciliationSheet: View {
    @EnvironmentObject var store: TimerStore
    let reconciliation: TimerStore.SleepReconciliation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "Mac slept \(sleepDurationString)")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.projectColor(for: reconciliation.project))
                        .frame(width: 7, height: 7)
                    Text(store.projectTitle(for: reconciliation.project))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(store.activityTitle(for: reconciliation.activity))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let desc = reconciliation.description, !desc.isEmpty {
                    Text("\u{201C}\(desc)\u{201D}")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("Sleep \(formatted(reconciliation.sleepStart)) → Wake \(formatted(reconciliation.wakeAt))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Keep as-is") {
                    store.keepRunning()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Backdate stop") {
                    store.backdateStopToSleep()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Split at wake") {
                    store.splitAtSleep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var sleepDurationString: String {
        let seconds = Int(reconciliation.wakeAt.timeIntervalSince(reconciliation.sleepStart))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    private func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}
