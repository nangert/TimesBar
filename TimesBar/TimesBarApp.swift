import SwiftUI

@main
struct TimesBarApp: App {
    @StateObject private var store = TimerStore()
    // Held for app lifetime so sleep/wake notifications keep firing.
    @State private var sleepObserver: SleepObserver?

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .task {
                    store.bootstrap()
                    if sleepObserver == nil {
                        let s = store
                        sleepObserver = SleepObserver { event in
                            Task { @MainActor in
                                switch event {
                                case .willSleep(let at): s.handleWillSleep(at: at)
                                case .didWake(let at):   s.handleDidWake(at: at)
                                }
                            }
                        }
                    }
                    // Restore the global hotkey if it was enabled in a prior session.
                    store.applyHotkeyPref()
                }
                .onOpenURL { url in
                    if let action = URLActionRouter.parse(url) {
                        store.handle(urlAction: action)
                    }
                }
        } label: {
            MenuBarLabel()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
