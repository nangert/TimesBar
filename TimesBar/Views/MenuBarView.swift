import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore

    /// Which panel is mounted in the dropdown. Replaces a row of Bool flags
    /// that previously had to be manually reset on every transition — easy to
    /// forget one and end up with overlapping panels.
    private enum Route: Equatable {
        case main, settings, startForm, editActiveTimer, timeOff, monthlyBalance
        case editTimesheet(TimesheetEntity)
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
                if let rec = store.pendingSleepReconciliation {
                    SleepReconciliationSheet(reconciliation: rec)
                        .environmentObject(store)
                    Divider()
                }
                if let toast = store.autoStopToast {
                    AutoStopToastView(toast: toast)
                        .environmentObject(store)
                    Divider()
                }
                switch route {
                case .settings:
                    SettingsView(
                        onCancel: { route = .main },
                        onSaved: { route = .main }
                    )
                case .timeOff:
                    TimeOffView(onClose: { route = .main })
                case .monthlyBalance:
                    MonthlyBalanceView(onClose: { route = .main })
                case .editActiveTimer:
                    if store.active != nil {
                        EditActiveTimerForm(
                            onCancel: { route = .main },
                            onSaved: { route = .main }
                        )
                        .environmentObject(store)
                    } else {
                        // Timer was stopped from another client mid-edit;
                        // drop back to main rather than showing a stale form.
                        authenticatedContent
                            .onAppear { route = .main }
                    }
                case .editTimesheet(let entry):
                    EditTimesheetForm(
                        entry: entry,
                        onCancel: { route = .main },
                        onSaved: { route = .main }
                    )
                    .environmentObject(store)
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
        .frame(width: dropdownWidth)
    }

    /// The forms with the calendar grid + time-range bar need more room than
    /// the default menu width. Other panels stay compact.
    private var dropdownWidth: CGFloat {
        switch route {
        case .startForm, .editActiveTimer, .editTimesheet: return 420
        default: return 320
        }
    }

    @ViewBuilder private var authenticatedContent: some View {
        if let timesheet = store.active {
            ActiveTimerSection(
                projectTitle: store.projectTitle(for: timesheet.project),
                description: timesheet.description,
                elapsed: store.elapsedString,
                projectColor: store.projectColor(for: timesheet.project),
                onStop: { Task { await store.stop() } },
                onEdit: { route = .editActiveTimer }
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
                    },
                    onEdit: { item in
                        guard let entry = store.recent.first(where: { $0.id == item.id }) else { return }
                        route = .editTimesheet(entry)
                    },
                    onDuplicate: { item in
                        Task { await store.duplicateTimesheet(id: item.id) }
                    },
                    onDelete: { item in
                        Task { await store.deleteTimesheet(id: item.id) }
                    },
                    colorForProject: { store.projectColor(for: $0) }
                )
            }
        }
        Divider()
        TotalsSection(weekHours: store.weekHours,
                      todayHours: store.todayHours,
                      dailyTargetHours: store.hoursPerWorkingDay,
                      weekProjectHours: store.weekProjectHours,
                      colorForProject: { store.projectColor(for: $0) })
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
                    durationSeconds: (entry.end ?? Date()).timeIntervalSince(entry.begin),
                    tags: entry.tags
                )
            }
    }
}
