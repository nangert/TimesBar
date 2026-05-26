import AppKit
import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var store: TimerStore

    var body: some View {
        Group {
            if store.isRunning {
                // Running: show a filled timer icon + elapsed time
                Label {
                    Text(store.elapsedString)
                        .font(.system(.body, design: .monospaced))
                } icon: {
                    Image(systemName: "timer")
                }
            } else {
                // Idle: just the icon (SwiftUI renders this as a template image in the menu bar)
                Image(systemName: "timer")
            }
        }
        .contextMenu {
            // Start last activity — only available when idle and there is a recent entry.
            Button("Start last activity") {
                guard let lastId = store.recent.first?.id else { return }
                Task { await store.resumeCheckingResult(timesheetId: lastId) }
            }
            .disabled(store.active != nil || store.recent.isEmpty)

            // Stop timer — only available when a timer is running.
            Button("Stop timer") {
                Task { await store.stop() }
            }
            .disabled(store.active == nil)

            Divider()

            // Open the configured Kimai instance in the user's default browser —
            // matches kimai-clock's "long-press the menu bar icon" gesture without
            // requiring a NSStatusItem rewrite (MenuBarExtra can't intercept the
            // long-press cleanly).
            Button("Open Kimai") {
                NSWorkspace.shared.open(UserPreferences.shared.baseURL)
            }

            // "Log past entry…" is intentionally omitted in v1: MenuBarExtra does not
            // expose a programmatic API to open its window from a context-menu action,
            // so we cannot reliably route into the past-entry form without rewriting
            // the entire app-lifecycle entry point. Deferred to a future release.
        }
    }
}
