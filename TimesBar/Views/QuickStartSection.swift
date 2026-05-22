import SwiftUI

struct QuickStartItem: Identifiable, Equatable {
    let id: Int
    let projectId: Int
    let activityId: Int
    let description: String?
    let title: String
    let durationSeconds: TimeInterval
}

struct QuickStartSection: View {
    let items: [QuickStartItem]
    let errorMessage: String?
    let onStart: (QuickStartItem) -> Void
    let onStartNew: () -> Void
    var colorForProject: (Int) -> Color = { id in Color.forProject(id: id, hex: nil) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: "Quick start")
                Spacer()
                Button(action: onStartNew) {
                    Label("Start new", systemImage: "plus.circle")
                        .font(.system(size: 11, weight: .medium))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            if items.isEmpty {
                Text("No recent entries")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                VStack(spacing: 2) {
                    ForEach(items) { item in
                        QuickStartRow(item: item,
                                      projectColor: colorForProject(item.projectId)) {
                            onStart(item)
                        }
                    }
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct QuickStartRow: View {
    let item: QuickStartItem
    let projectColor: Color
    let onTap: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Circle()
                    .fill(projectColor)
                    .frame(width: 6, height: 6)
                Text(item.title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(formatHoursAndMinutes(seconds: item.durationSeconds))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(hover ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
