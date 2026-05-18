import SwiftUI

@main
struct TimesBarApp: App {
    @StateObject private var store = TimerStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .frame(width: 320)
                .onAppear { store.bootstrap() }
        } label: {
            MenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
