import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.isAuthenticated {
                Text("Sign in to Kimai in Settings")
                    .foregroundStyle(.secondary)
            } else if let timesheet = store.active {
                ActiveTimerSection(timesheet: timesheet,
                                    elapsed: store.elapsedString) {
                    Task { await store.stop() }
                }
            } else {
                Text("No active timer").foregroundStyle(.secondary)
            }
            Divider()
            FooterRow()
        }
        .padding(12)
    }
}

struct FooterRow: View {
    var body: some View {
        HStack {
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
            Spacer()
        }
    }
}
