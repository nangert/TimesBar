import AppKit
import UserNotifications

/// Watches NSWorkspace for activations of the apps the user opted into and
/// fires a User Notification when one comes up without a Kimai timer running.
///
/// Debounce rule: at most one notification per "no-timer session" — once a
/// reminder fires, no more notifications come through until the user starts
/// (then stops) a timer. Without the reset hook, activating VS Code 50 times
/// in a day would mean 50 banners.
@MainActor
final class LaunchReminderObserver {
    weak var store: TimerStore?

    private var workspaceObserver: NSObjectProtocol?
    private var firedSinceLastTimerStart = false

    nonisolated static let categoryIdentifier = "LAUNCH_REMINDER"
    nonisolated static let actionIdentifierStartLast = "START_LAST"

    /// Register the notification category so the banner exposes a "Start last
    /// activity" action button. Call once at app launch.
    static func registerCategories() {
        let action = UNNotificationAction(
            identifier: actionIdentifierStartLast,
            title: String(localized: "Start last activity"),
            options: [])
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [action],
            intentIdentifiers: [],
            options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Ask the user for permission. Returns true if granted (or already granted).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Start observing. Idempotent — calling `start()` twice is a no-op.
    func start() {
        guard workspaceObserver == nil else { return }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract Sendable strings synchronously on the main queue so the
            // non-Sendable Notification doesn't have to cross the actor hop.
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleId = app?.bundleIdentifier
            let appName = app?.localizedName
            Task { @MainActor in self?.handle(bundleId: bundleId, appName: appName) }
        }
    }

    func stop() {
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
        firedSinceLastTimerStart = false
    }

    /// TimerStore calls this whenever a timer transitions into running. Resets
    /// the debounce so the *next* no-timer interval can fire one reminder.
    func timerStarted() {
        firedSinceLastTimerStart = false
    }

    // MARK: - Pure helper (testable)

    /// Returns true if an activation of `bundleId` should fire a reminder.
    /// All decision inputs live in the parameters so unit tests don't have
    /// to spin up NSWorkspace or UserPreferences.
    nonisolated static func shouldFire(bundleId: String,
                                       isEnabled: Bool,
                                       watchedBundleIds: Set<String>,
                                       isTimerRunning: Bool,
                                       firedSinceLastTimerStart: Bool) -> Bool {
        guard isEnabled,
              watchedBundleIds.contains(bundleId),
              !isTimerRunning,
              !firedSinceLastTimerStart else { return false }
        return true
    }

    private func handle(bundleId: String?, appName: String?) {
        guard let bundleId else { return }

        guard Self.shouldFire(
            bundleId: bundleId,
            isEnabled: UserPreferences.shared.launchReminderEnabled,
            watchedBundleIds: UserPreferences.shared.launchReminderBundleIds,
            isTimerRunning: store?.isRunning ?? false,
            firedSinceLastTimerStart: firedSinceLastTimerStart
        ) else { return }

        firedSinceLastTimerStart = true
        send(appName: appName ?? bundleId)
    }

    private func send(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "TimesBar"
        content.body = String(
            format: String(localized: "You're using %@ but no timer is running."),
            appName)
        content.categoryIdentifier = Self.categoryIdentifier
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

/// Handles delegate callbacks from UNUserNotificationCenter — keeps banners
/// visible while the menu bar dropdown is open, and routes the "Start last
/// activity" tap into the store.
///
/// `@unchecked Sendable` is safe here: the only mutable field is `store`,
/// which is `@MainActor` isolated, and the delegate methods immediately hop
/// back to the main actor before touching it.
final class NotificationActionHandler: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationActionHandler()

    @MainActor weak var store: TimerStore?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        if action == LaunchReminderObserver.actionIdentifierStartLast {
            Task { @MainActor in
                guard let store = self.store, let lastId = store.recent.first?.id else { return }
                _ = await store.resumeCheckingResult(timesheetId: lastId)
            }
        }
        completionHandler()
    }
}
