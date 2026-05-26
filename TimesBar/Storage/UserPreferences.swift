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
