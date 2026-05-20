import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    @State private var showingSettings = false
    @State private var showingStartForm = false
    @State private var showingTimeOff = false
    @State private var showingMonthlyBalance = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.isAuthenticated {
                TokenSetupForm(onCancel: nil) {
                    // saved successfully — drop back to the normal dropdown
                }
            } else if showingSettings {
                TokenSetupForm(
                    onCancel: { showingSettings = false },
                    onSaved: { showingSettings = false }
                )
            } else if showingTimeOff {
                TimeOffView(onClose: { showingTimeOff = false })
            } else if showingMonthlyBalance {
                MonthlyBalanceView(onClose: { showingMonthlyBalance = false })
            } else {
                authenticatedContent
            }
            Divider()
            FooterRow(
                onSettings: { showingSettings.toggle() },
                onTimeOff: {
                    showingTimeOff = true
                    showingSettings = false
                    showingStartForm = false
                    showingMonthlyBalance = false
                },
                onMonthlyBalance: {
                    showingMonthlyBalance = true
                    showingSettings = false
                    showingStartForm = false
                    showingTimeOff = false
                },
                onSignOut: {
                    store.signOut()
                    showingSettings = false
                    showingStartForm = false
                    showingTimeOff = false
                    showingMonthlyBalance = false
                }
            )
        }
        .padding(14)
    }

    @ViewBuilder private var authenticatedContent: some View {
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

    private var quickStartItems: [QuickStartItem] {
        store.recent
            .filter { $0.end != nil }
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
}
