import SwiftUI

struct IdlePromptSheet: View {
    @EnvironmentObject var store: TimerStore
    let prompt: TimerStore.IdlePrompt

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "You've been idle for \(idleDurationString)")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(store.projectColor(for: prompt.project))
                        .frame(width: 7, height: 7)
                    Text(store.projectTitle(for: prompt.project))
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(store.activityTitle(for: prompt.activity))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let desc = prompt.description, !desc.isEmpty {
                    Text("\u{201C}\(desc)\u{201D}")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
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
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private var idleDurationString: String {
        let seconds = Int(Date().timeIntervalSince(prompt.idleStart))
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
