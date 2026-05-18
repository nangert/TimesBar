import SwiftUI

@main
struct TimesBarApp: App {
    var body: some Scene {
        MenuBarExtra("TimesBar", systemImage: "timer") {
            VStack(alignment: .leading, spacing: 8) {
                Text("TimesBar")
                    .font(.headline)
                Text("scaffold ok")
                    .foregroundStyle(.secondary)
                Divider()
                Button("Quit TimesBar") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(12)
            .frame(width: 240)
        }
        .menuBarExtraStyle(.window)
    }
}
