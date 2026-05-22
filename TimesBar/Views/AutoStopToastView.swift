import SwiftUI

struct AutoStopToastView: View {
    @EnvironmentObject var store: TimerStore
    let toast: TimerStore.AutoStopToast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("Auto-stopped at \(formatted(toast.stoppedAt))")
                .font(.system(size: 12))
                .foregroundStyle(.primary)

            Spacer()

            Button("Undo") {
                store.undoAutoStop()
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Button {
                store.autoStopToast = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
    }

    private func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}
