import SwiftUI

struct MenuBarLabel: View {
    @EnvironmentObject var store: TimerStore

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(store.isRunning ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            if store.isRunning {
                Text(store.elapsedString)
                    .font(.system(.body, design: .monospaced))
            }
            Sparkline(values: store.weekHours)
                .frame(width: 48, height: 14)
        }
    }
}
