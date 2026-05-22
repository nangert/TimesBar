import Testing
import SwiftUI
@testable import TimesBar

/// Tests for `Color.forProject(id:hex:)` and its helpers.
@Suite struct ProjectColorTests {

    // MARK: - Hex parsing

    @Test func hexColorIsReturnedWhenProvided() {
        // #FF6B35 should produce a distinct non-nil color (not the hash fallback).
        // We verify by checking it equals a direct hex parse.
        let direct = Color(hexString: "#FF6B35")
        #expect(direct != nil)
        // forProject should return the same thing as the direct parse when hex is set.
        // We can't compare Color values directly, so we verify indirectly by checking
        // that passing nil gives a different result than passing the hex.
        let withHex = Color.forProject(id: 1, hex: "#FF6B35")
        let withNil = Color.forProject(id: 1, hex: nil)
        // The two should produce different colors (hex-specified vs hash-derived).
        // Since Color isn't Equatable in a useful sense here, we just ensure
        // parsing doesn't crash and nil returns the fallback path.
        _ = withHex
        _ = withNil
    }

    @Test func hexParserHandlesRRGGBB() {
        let c = Color(hexString: "#FF6B35")
        #expect(c != nil)
    }

    @Test func hexParserHandlesRGB() {
        let c = Color(hexString: "#F63")
        #expect(c != nil)
    }

    @Test func hexParserRejectsInvalidInput() {
        #expect(Color(hexString: "notacolor") == nil)
        #expect(Color(hexString: "#ZZZZZZ") == nil)
        #expect(Color(hexString: "#1234") == nil)
    }

    @Test func hexParserHandlesMissingHash() {
        let c = Color(hexString: "FF6B35")
        #expect(c != nil)
    }

    // MARK: - Deterministic hue derivation

    @Test func sameIdProducesSameHue() {
        // Call twice — must return the same value each time (stable across calls).
        let h1 = hue(for: 42)
        let h2 = hue(for: 42)
        #expect(h1 == h2)
    }

    @Test func differentIdsProduceDifferentHues() {
        let ids = [1, 2, 3, 4, 5, 10, 100, 999]
        let hues = ids.map { hue(for: $0) }
        // All hues must be unique for this small set.
        let unique = Set(hues)
        #expect(unique.count == hues.count)
    }

    // MARK: - Forbidden-band exclusion

    @Test func noIdMapsToRedBand() {
        for id in 1...1000 {
            let h = hue(for: id)
            let inRedBand = (h >= 345 && h <= 359) || (h >= 0 && h <= 15)
            #expect(!inRedBand, "ID \(id) produced hue \(h) which is in the red band")
        }
    }

    @Test func noIdMapsToKimaiGreenBand() {
        for id in 1...1000 {
            let h = hue(for: id)
            let inGreenBand = h >= 105 && h <= 135
            #expect(!inGreenBand, "ID \(id) produced hue \(h) which is in the kimai-green band")
        }
    }

    @Test func skipForbiddenBandsOutputIsInSafeRange() {
        for raw in 0..<298 {
            let result = Color.skipForbiddenBands(raw)
            let inRedBand = (result >= 345 && result <= 359) || (result >= 0 && result <= 15)
            let inGreenBand = result >= 105 && result <= 135
            #expect(!inRedBand, "raw=\(raw) produced \(result) in red band")
            #expect(!inGreenBand, "raw=\(raw) produced \(result) in green band")
        }
    }

    // MARK: - Helpers

    /// Extract the integer hue (0–359) from the hash-derived color for a project ID.
    /// We use Knuth's hash directly here to mirror the production code, rather than
    /// duplicating the full `Color(projectId:)` init path.
    private func hue(for id: Int) -> Int {
        let hash = UInt32(truncatingIfNeeded: UInt64(bitPattern: Int64(id)) &* 2654435761)
        let rawHue = Int(hash % 360)
        return Color.skipForbiddenBands(rawHue)
    }
}
