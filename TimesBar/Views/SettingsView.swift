import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TimerStore
    @ObservedObject private var prefs = UserPreferences.shared

    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var urlText: String = ""
    @State private var urlError: String?
    @State private var isSavingURL = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TokenSetupForm(
                onCancel: onCancel,
                onSaved: onSaved
            )

            Divider()

            serverSection

            Divider()

            behaviorSection

            Divider()

            launchRemindersSection
        }
        .onAppear {
            urlText = prefs.baseURL.absoluteString
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "Server")

            FormRow(label: "Base URL") {
                TextField("https://your-kimai-instance.example.com", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .pillFieldStyle()
                    .onSubmit(saveURL)
                    .onChange(of: urlText) { _, _ in
                        urlError = nil
                    }
            }

            if let urlError {
                Text(urlError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(action: saveURL) {
                    Label(isSavingURL ? "Saving…" : "Save URL",
                          systemImage: "checkmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isSavingURL)
            }
        }
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "Behavior")

            Toggle("Auto-stop timer at end of day", isOn: $prefs.autoStopEnabled)
                .toggleStyle(.switch)
                .font(.system(size: 12))

            if prefs.autoStopEnabled {
                FormRow(label: "Stop at") {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                let comps = prefs.autoStopTime
                                var cal = Calendar.current
                                cal.timeZone = .current
                                return cal.date(bySettingHour: comps.hour ?? 19,
                                               minute: comps.minute ?? 0,
                                               second: 0,
                                               of: Date()) ?? Date()
                            },
                            set: { date in
                                let cal = Calendar.current
                                let hour   = cal.component(.hour,   from: date)
                                let minute = cal.component(.minute, from: date)
                                prefs.autoStopTime = DateComponents(hour: hour, minute: minute)
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .datePickerStyle(.field)
                }
            }

            Toggle("Global hotkey (⌘⌥T) toggles timer", isOn: $prefs.hotkeyEnabled)
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .onChange(of: prefs.hotkeyEnabled) { _, _ in
                    store.applyHotkeyPref()
                }

            Toggle("Prompt when idle", isOn: $prefs.idleDetectionEnabled)
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .onChange(of: prefs.idleDetectionEnabled) { _, _ in
                    store.restartIdleMonitor()
                }

            if prefs.idleDetectionEnabled {
                FormRow(label: "Idle threshold (min)") {
                    Stepper(
                        value: Binding(
                            get: { prefs.idleThresholdMinutes },
                            set: { prefs.idleThresholdMinutes = min(60, max(5, $0)) }
                        ),
                        in: 5...60,
                        step: 5
                    ) {
                        Text("\(prefs.idleThresholdMinutes)")
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .onChange(of: prefs.idleThresholdMinutes) { _, _ in
                        store.restartIdleMonitor()
                    }
                }
            }
        }
    }

    private var launchRemindersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "Launch reminders")

            Toggle("Remind me to start a timer when I open dev tools",
                   isOn: launchReminderToggle)
                .toggleStyle(.switch)
                .font(.system(size: 12))

            if prefs.launchReminderEnabled {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(launchReminderKnownApps, id: \.bundleId) { app in
                        Toggle(app.label, isOn: appToggle(for: app.bundleId))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 11))
                    }
                }
                .padding(.leading, 6)
                .padding(.top, 2)
            }
        }
    }

    /// Binding for the master toggle. Side-effects: kicks the observer to
    /// reflect the new state and, on enable, asks for notification permission.
    private var launchReminderToggle: Binding<Bool> {
        Binding(
            get: { prefs.launchReminderEnabled },
            set: { newValue in
                prefs.launchReminderEnabled = newValue
                store.applyLaunchReminderPref()
                if newValue {
                    Task { _ = await LaunchReminderObserver.requestAuthorization() }
                }
            }
        )
    }

    private func appToggle(for bundleId: String) -> Binding<Bool> {
        Binding(
            get: { prefs.launchReminderBundleIds.contains(bundleId) },
            set: { newValue in
                var set = prefs.launchReminderBundleIds
                if newValue { set.insert(bundleId) } else { set.remove(bundleId) }
                prefs.launchReminderBundleIds = set
            }
        )
    }

    private func saveURL() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSavingURL else { return }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              (scheme == "https" || scheme == "http"),
              url.host != nil else {
            urlError = String(localized: "Enter a valid URL starting with https:// or http://")
            return
        }

        isSavingURL = true
        prefs.baseURL = url
        Task {
            await store.rebuildClient()
            isSavingURL = false
            onSaved()
        }
    }
}
