import SwiftUI

/// Compact banner shown in place of the "No active timer" placeholder when the
/// user has paused an entry. One-click Resume restarts the paused entry via
/// Kimai's `/restart?copy=all`. Dismiss clears the paused state and falls back
/// to the normal quick-start UI.
struct PausedBanner: View {
    let projectTitle: String
    let projectColor: Color
    let description: String?
    let onResume: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Paused")
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(2)
                }
                .buttonStyle(.plain)
                .help("Dismiss paused entry")
            }
            HStack(spacing: 8) {
                Circle()
                    .fill(projectColor)
                    .frame(width: 7, height: 7)
                Text(projectTitle)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            if let description, !description.isEmpty {
                Text("“\(description)”")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack {
                Spacer()
                Button(action: onResume) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.system(size: 12, weight: .medium))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
            }
        }
    }
}
