import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore

    /// Which panel is mounted in the dropdown. Replaces a row of Bool flags
    /// that previously had to be manually reset on every transition — easy to
    /// forget one and end up with overlapping panels.
    private enum Route {
        case main, settings, startForm, timeOff, monthlyBalance
    }
    @State private var route: Route = .main
    @State private var quickStartError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !store.isAuthenticated {
                TokenSetupForm(onCancel: nil) {
                    // saved successfully — drop back to the normal dropdown
                }
            } else {
                switch route {
                case .settings:
                    TokenSetupForm(
                        onCancel: { route = .main },
                        onSaved: { route = .main }
                    )
                case .timeOff:
                    TimeOffView(onClose: { route = .main })
                case .monthlyBalance:
                    MonthlyBalanceView(onClose: { route = .main })
                case .main, .startForm:
                    authenticatedContent
                }
            }
            Divider()
            FooterRow(
                onSettings: { route = (route == .settings ? .main : .settings) },
                onTimeOff: { route = .timeOff },
                onMonthlyBalance: { route = .monthlyBalance },
                onSignOut: {
                    store.signOut()
                    route = .main
                    quickStartError = nil
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
            if route == .startForm {
                StartTimerForm(
                    onCancel: { route = .main },
                    onStarted: { route = .main }
                )
                .environmentObject(store)
            } else {
                QuickStartSection(
                    items: quickStartItems,
                    errorMessage: quickStartError,
                    onStart: { item in
                        quickStartError = nil
                        Task {
                            // Use Kimai's /restart endpoint instead of POSTing a
                            // fresh /timesheets entry so description + tags are
                            // copied automatically (`copy=all`).
                            let ok = await store.resumeCheckingResult(timesheetId: item.id)
                            if !ok {
                                quickStartError = "Kimai rejected the request. The activity may not belong to that project anymore."
                            }
                        }
                    },
                    onStartNew: {
                        quickStartError = nil
                        route = .startForm
                    }
                )
            }
        }
        Divider()
        TotalsSection(weekHours: store.weekHours,
                      dailyTargetHours: store.hoursPerWorkingDay)
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
