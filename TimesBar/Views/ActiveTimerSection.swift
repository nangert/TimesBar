import SwiftUI

struct ActiveTimerSection: View {
    let timesheet: TimesheetEntity
    let elapsed: String
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timesheet.description ?? "Project #\(timesheet.project)")
                        .font(.headline)
                        .lineLimit(1)
                    Text("Activity #\(timesheet.activity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(elapsed)
                    .font(.system(.title3, design: .monospaced))
            }
            Button(role: .destructive, action: onStop) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }
}
