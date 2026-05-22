import Foundation
import Combine

private let baseURLKey = "kimaiBaseURL"
private let defaultBaseURL = URL(string: "https://times.lipsum.services")!

@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    /// The Kimai instance base URL. Defaults to `https://times.lipsum.services`.
    @Published var baseURL: URL {
        didSet {
            UserDefaults.standard.set(baseURL, forKey: baseURLKey)
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
    }
}
