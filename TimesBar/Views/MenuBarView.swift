import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: TimerStore
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TimesBar").font(.headline)
            Text(store.isAuthenticated ? "Connected" : "Not connected")
                .foregroundStyle(.secondary)
            Divider()
            Button("Quit TimesBar") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        .padding(12)
    }
}
