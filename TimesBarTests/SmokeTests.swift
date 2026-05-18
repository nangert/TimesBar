import Testing
import Foundation
@testable import TimesBar

@Test func appBundleIsReachable() {
    let bundle = Bundle(for: BundleAnchor.self)
    #expect(bundle.bundleIdentifier != nil)
}

final class BundleAnchor {}
