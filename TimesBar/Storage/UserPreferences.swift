import Foundation
import Combine

private let baseURLKey = "kimaiBaseURL"
private let defaultBaseURL = URL(string: "https://times.lipsum.services")!

private let autoStopEnabledKey = "autoStopEnabled"
private let autoStopHourKey    = "autoStopHour"
private let autoStopMinuteKey  = "autoStopMinute"

private let defaultAutoStopHour   = 19
private let defaultAutoStopMinute = 0

private let idleDetectionEnabledKey   = "idleDetectionEnabled"
private let idleThresholdMinutesKey   = "idleThresholdMinutes"
private let defaultIdleThresholdMinutes = 15

private let hotkeyEnabledKey = "hotkeyEnabled"

private let pausedEntryIdKey = "pausedEntryId"

private let launchReminderEnabledKey = "launchReminderEnabled"
private let launchReminderBundleIdsKey = "launchReminderBundleIds"

/// Curated default set of dev-tool bundle IDs that trigger a "you don't have
/// a timer running" reminder on first activation. The user can opt apps in
/// or out via SettingsView; this is the seed list on first launch.
let defaultLaunchReminderBundleIds: Set<String> = [
    "com.microsoft.VSCode",       // VS Code
    "com.apple.dt.Xcode",         // Xcode
    "com.jetbrains.PhpStorm",     // PhpStorm
    "com.jetbrains.intellij",     // IntelliJ IDEA (Ultimate)
    "com.jetbrains.intellij.ce",  // IntelliJ IDEA (CE)
    "com.jetbrains.PyCharm",      // PyCharm Professional
    "com.jetbrains.WebStorm",     // WebStorm
    "com.jetbrains.goland",       // GoLand
    "dev.zed.Zed",                // Zed
    "com.todesktop.230313mzl4w4u92", // Cursor
]

/// User-facing display labels for the bundle IDs we know about. Unknown
/// bundle IDs fall back to NSRunningApplication.localizedName at runtime.
let launchReminderKnownApps: [(bundleId: String, label: String)] = [
    ("com.microsoft.VSCode", "Visual Studio Code"),
    ("com.apple.dt.Xcode", "Xcode"),
    ("com.jetbrains.PhpStorm", "PhpStorm"),
    ("com.jetbrains.intellij", "IntelliJ IDEA"),
    ("com.jetbrains.intellij.ce", "IntelliJ IDEA CE"),
    ("com.jetbrains.PyCharm", "PyCharm"),
    ("com.jetbrains.WebStorm", "WebStorm"),
    ("com.jetbrains.goland", "GoLand"),
    ("dev.zed.Zed", "Zed"),
    ("com.todesktop.230313mzl4w4u92", "Cursor"),
]

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    /// The Kimai instance base URL. Defaults to `https://times.lipsum.services`.
    @Published var baseURL: URL {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: baseURLKey)
        }
    }

    /// Whether end-of-day auto-stop is active. Defaults to `false`.
    @Published var autoStopEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoStopEnabled, forKey: autoStopEnabledKey)
        }
    }

    /// Whether the global ⌘⌥T hotkey is active. Defaults to `false`.
    @Published var hotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hotkeyEnabled, forKey: hotkeyEnabledKey)
        }
    }

    /// Whether idle-detection prompts are active. Defaults to `false`.
    @Published var idleDetectionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(idleDetectionEnabled, forKey: idleDetectionEnabledKey)
        }
    }

    /// Minutes of no input before the idle prompt fires. Persisted as a single
    /// Int. Clamped to 5–60 by the UI.
    @Published var idleThresholdMinutes: Int {
        didSet {
            UserDefaults.standard.set(idleThresholdMinutes, forKey: idleThresholdMinutesKey)
        }
    }

    /// Whether the "remind me to start a timer when I open VS Code/Xcode/…"
    /// banner is active. Off by default — gated on a User Notifications
    /// permission prompt the first time the user enables it.
    @Published var launchReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(launchReminderEnabled, forKey: launchReminderEnabledKey)
        }
    }

    /// Bundle IDs whose activation should trigger the reminder. Persisted as
    /// a comma-separated string so the underlying UserDefaults entry stays
    /// trivially debuggable from `defaults read`.
    @Published var launchReminderBundleIds: Set<String> {
        didSet {
            UserDefaults.standard.set(
                launchReminderBundleIds.sorted().joined(separator: ","),
                forKey: launchReminderBundleIdsKey)
        }
    }

    /// ID of the timesheet the user paused — set by `TimerStore.pause()`, cleared
    /// when the user resumes it, starts something else, or signs out. `nil` means
    /// there is no paused entry to resume. Survives app relaunches so a Mac
    /// reboot in the middle of a pause still surfaces the Resume affordance.
    @Published var pausedEntryId: Int? {
        didSet {
            if let id = pausedEntryId {
                UserDefaults.standard.set(id, forKey: pausedEntryIdKey)
            } else {
                UserDefaults.standard.removeObject(forKey: pausedEntryIdKey)
            }
        }
    }

    /// The time of day at which a running timer is automatically stopped.
    /// Persisted as two integers (hour, minute). Defaults to 19:00.
    @Published var autoStopTime: DateComponents {
        didSet {
            UserDefaults.standard.set(autoStopTime.hour   ?? defaultAutoStopHour,
                                      forKey: autoStopHourKey)
            UserDefaults.standard.set(autoStopTime.minute ?? defaultAutoStopMinute,
                                      forKey: autoStopMinuteKey)
        }
    }

    private init() {
        if let stored = UserDefaults.standard.url(forKey: baseURLKey) {
            baseURL = stored
        } else if let raw = UserDefaults.standard.string(forKey: baseURLKey),
                  let url = URL(string: raw) {
            baseURL = url
        } else {
            baseURL = defaultBaseURL
        }

        autoStopEnabled = UserDefaults.standard.bool(forKey: autoStopEnabledKey)

        hotkeyEnabled = UserDefaults.standard.bool(forKey: hotkeyEnabledKey)

        idleDetectionEnabled = UserDefaults.standard.bool(forKey: idleDetectionEnabledKey)

        if UserDefaults.standard.object(forKey: idleThresholdMinutesKey) != nil {
            idleThresholdMinutes = UserDefaults.standard.integer(forKey: idleThresholdMinutesKey)
        } else {
            idleThresholdMinutes = defaultIdleThresholdMinutes
        }

        if UserDefaults.standard.object(forKey: pausedEntryIdKey) != nil {
            pausedEntryId = UserDefaults.standard.integer(forKey: pausedEntryIdKey)
        } else {
            pausedEntryId = nil
        }

        launchReminderEnabled = UserDefaults.standard.bool(forKey: launchReminderEnabledKey)

        if let csv = UserDefaults.standard.string(forKey: launchReminderBundleIdsKey) {
            launchReminderBundleIds = Set(
                csv.split(separator: ",").map { String($0) }.filter { !$0.isEmpty })
        } else {
            launchReminderBundleIds = defaultLaunchReminderBundleIds
        }

        let storedHour: Int
        let storedMinute: Int
        if UserDefaults.standard.object(forKey: autoStopHourKey) != nil,
           UserDefaults.standard.object(forKey: autoStopMinuteKey) != nil {
            storedHour   = UserDefaults.standard.integer(forKey: autoStopHourKey)
            storedMinute = UserDefaults.standard.integer(forKey: autoStopMinuteKey)
        } else {
            storedHour   = defaultAutoStopHour
            storedMinute = defaultAutoStopMinute
        }
        autoStopTime = DateComponents(hour: storedHour, minute: storedMinute)
    }
}
