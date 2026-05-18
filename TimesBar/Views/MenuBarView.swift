import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    @State private var showingSettings = false
    @State private var showingStartForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.isAuthenticated {
                signInBlock
            } else {
                if let timesheet = store.active {
                    ActiveTimerSection(
                        projectTitle: store.projectTitle(for: timesheet.project),
                        description: timesheet.description,
                        elapsed: store.elapsedString,
                        onStop: { Task { await store.stop() } }
                    )
                } else {
                    SectionHeader(text: "Active")
                    Text("No active timer")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                if store.active == nil {
                    Divider()
                    if showingStartForm {
                        StartTimerForm(
                            onCancel: { showingStartForm = false },
                            onStarted: { showingStartForm = false }
                        )
                        .environmentObject(store)
                    } else {
                        QuickStartSection(
                            items: quickStartItems,
                            onStart: { item in
                                Task {
                                    await store.start(project: item.projectId,
                                                      activity: item.activityId,
                                                      description: item.description)
                                }
                            },
                            onStartNew: { showingStartForm = true }
                        )
                    }
                }
                Divider()
                TotalsSection(weekHours: store.weekHours)
            }
            Divider()
            FooterRow(
                onSettings: { showingSettings = true },
                onSignOut: { store.signOut() }
            )
        }
        .padding(14)
        .sheet(isPresented: $showingSettings) {
            TokenSetupSheet().environmentObject(store)
        }
    }

    private var quickStartItems: [QuickStartItem] {
        store.recent
            .filter { $0.end != nil }   // only show stopped past entries
            .prefix(3)
            .map { entry in
                QuickStartItem(
                    id: entry.id,
                    projectId: entry.project,
                    activityId: entry.activity,
                    description: entry.description,
                    title: store.projectTitle(for: entry.project),
                    durationSeconds: (entry.end ?? Date()).timeIntervalSince(entry.begin)
                )
            }
    }

    @ViewBuilder private var signInBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sign in to Kimai")
                .font(.system(size: 14, weight: .semibold))
            Text("Add an API token to start tracking.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("Sign in") { showingSettings = true }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .padding(.top, 4)
        }
    }
}
