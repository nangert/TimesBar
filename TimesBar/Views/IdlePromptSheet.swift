import SwiftUI

struct IdlePromptSheet: View {
    @EnvironmentObject var store: TimerStore
    let prompt: TimerStore.IdlePrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "You've been idle for \(idleDurationString)")

            VStack(alignment: .leading, spacing: 3) {
                TimesheetContextSummary(
                    projectTitle: store.projectTitle(for: prompt.project),
                    projectColor: store.projectColor(for: prompt.project),
                    activityTitle: store.activityTitle(for: prompt.activity),
                    description: prompt.description)
                Text("Idle since \(formatted(prompt.idleStart))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button("Keep elapsed time") {
                    store.keepIdleTime()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Backdate stop to when I went idle") {
                    store.backdateStopToIdle()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(10)
        .promptCardStyle()
    }

    private var idleDurationString: String {
        formatHoursAndMinutes(seconds: Date().timeIntervalSince(prompt.idleStart))
    }

    private func formatted(_ date: Date) -> String {
        timeHMFormatter.string(from: date)
    }
}
