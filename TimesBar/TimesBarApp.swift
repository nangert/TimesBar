import SwiftUI

@main
struct TimesBarApp: App {
    @StateObject private var store = TimerStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .onAppear { store.bootstrap() }
        } label: {
            MenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
