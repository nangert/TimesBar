import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var store: TimerStore
    var body: some View {
        Image(systemName: store.isRunning ? "timer" : "timer")
    }
}
