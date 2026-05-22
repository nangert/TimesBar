import Foundation
import Combine

private let baseURLKey = "kimaiBaseURL"
private let defaultBaseURL = URL(string: "https://times.lipsum.services")!

private let autoStopEnabledKey = "autoStopEnabled"
private let autoStopHourKey    = "autoStopHour"
private let autoStopMinuteKey  = "autoStopMinute"

private let defaultAutoStopHour   = 19
private let defaultAutoStopMinute = 0

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
