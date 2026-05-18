import SwiftUI

struct ActiveTimerSection: View {
    let projectTitle: String
    let description: String?
    let elapsed: String
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "Active")
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.kimaiGreen)
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
            HStack(alignment: .firstTextBaseline) {
                Text(elapsed)
                    .font(.system(size: 22, weight: .medium, design: .monospaced))
                    .tracking(1)
                Spacer()
                Button(action: onStop) {
                    Label("Stop", systemImage: "stop.fill")
                        .font(.system(size: 12, weight: .medium))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
                .tint(.kimaiStopTint)
                .controlSize(.small)
            }
        }
    }
}
