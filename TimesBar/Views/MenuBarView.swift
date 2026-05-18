import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    @State private var showingSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.isAuthenticated {
                Text("Sign in to Kimai")
                    .font(.headline)
                Text("Add an API token to start tracking.")
                    .foregroundStyle(.secondary)
                Button("Sign in") { showingSettings = true }
                    .buttonStyle(.borderedProminent)
            } else if let timesheet = store.active {
                ActiveTimerSection(timesheet: timesheet,
                                    elapsed: store.elapsedString) {
                    Task { await store.stop() }
                }
                Divider()
                TotalsSection(weekHours: store.weekHours)
            } else {
                Text("No active timer").foregroundStyle(.secondary)
                Divider()
                TotalsSection(weekHours: store.weekHours)
            }
            Divider()
            FooterRow(showSettings: { showingSettings = true })
        }
        .padding(12)
        .sheet(isPresented: $showingSettings) {
            TokenSetupSheet().environmentObject(store)
        }
    }
}

struct FooterRow: View {
    let showSettings: () -> Void
    var body: some View {
        HStack {
            Button("Settings", action: showSettings)
            Spacer()
            Button("Open Kimai") {
                if let url = URL(string: "https://times.lipsum.services") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .font(.caption)
    }
}

struct TokenSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack { Text("Settings (stub)"); Button("Close") { dismiss() } }.padding()
    }
}
