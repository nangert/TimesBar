import SwiftUI

struct SleepReconciliationSheet: View {
    @EnvironmentObject var store: TimerStore
    let reconciliation: TimerStore.SleepReconciliation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "Mac slept \(sleepDurationString)")

            VStack(alignment: .leading, spacing: 3) {
                TimesheetContextSummary(
                    projectTitle: store.projectTitle(for: reconciliation.project),
                    projectColor: store.projectColor(for: reconciliation.project),
                    activityTitle: store.activityTitle(for: reconciliation.activity),
                    description: reconciliation.description)
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
        .promptCardStyle()
    }

    private var sleepDurationString: String {
        formatHoursAndMinutes(seconds: reconciliation.wakeAt.timeIntervalSince(reconciliation.sleepStart))
    }

    private func formatted(_ date: Date) -> String {
        timeHMFormatter.string(from: date)
    }
}
