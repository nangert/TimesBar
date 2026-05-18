import SwiftUI

struct QuickStartSection: View {
    let recent: [TimesheetEntity]
    let onStart: (TimesheetEntity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Quick start").font(.caption).foregroundStyle(.secondary)
            if recent.isEmpty {
                Text("No recent entries").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(recent) { entry in
                    Button {
                        onStart(entry)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill").font(.caption)
                            Text(entry.description ?? "Project #\(entry.project) / Activity #\(entry.activity)")
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
