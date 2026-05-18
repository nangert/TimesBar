import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var store: TimerStore

    var body: some View {
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
}
