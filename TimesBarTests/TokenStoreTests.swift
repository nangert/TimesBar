import Testing
import Foundation
@testable import TimesBar

@Test func savesAndReadsToken() {
    let service = "bar.times.token.test.\(UUID().uuidString)"
    let store = TokenStore(service: service)
    defer { store.delete() }

    store.save("secret-token-xyz")
    #expect(store.read() == "secret-token-xyz")
}

@Test func overwritesExistingToken() {
    let service = "bar.times.token.test.\(UUID().uuidString)"
    let store = TokenStore(service: service)
    defer { store.delete() }

    store.save("first")
    store.save("second")
    #expect(store.read() == "second")
}

@Test func returnsNilWhenMissing() {
    let service = "bar.times.token.test.\(UUID().uuidString)"
    let store = TokenStore(service: service)
    #expect(store.read() == nil)
}
