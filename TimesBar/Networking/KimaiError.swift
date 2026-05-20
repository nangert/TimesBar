import Foundation

/// Typed errors thrown by `KimaiClient`. The store catches `.unauthorized` to
/// flip the auth state and route the user back to the token form; everything
/// else is logged and swallowed.
enum KimaiError: Error, Equatable, Sendable {
    case unauthorized
    case server(status: Int, body: String?)
    case decoding(String)
}
