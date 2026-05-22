import SwiftUI

extension Color {
    /// Matches the green used throughout the Kimai mockup (#3DDC7C).
    static let kimaiGreen = Color(red: 0.24, green: 0.86, blue: 0.49)
    /// Soft red tint for the Stop affordance, against dark/light surfaces.
    static let kimaiStopTint = Color(red: 1.0, green: 0.35, blue: 0.35)

    /// Stable per-project color. Uses the Kimai-side hex if present, else a
    /// deterministic hash-derived HSL color tuned for dark menu surfaces and
    /// distinct from kimaiGreen / kimaiStopTint.
    static func forProject(id: Int, hex: String?) -> Color {
        if let hex, let parsed = Color(hexString: hex) {
            return parsed
        }
        return Color(projectId: id)
    }

    /// Parse a `#RRGGBB` or `#RGB` hex string. Returns nil when the string is
    /// not a recognisable hex color.
    init?(hexString: String) {
        let s = hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString
        switch s.count {
        case 6:
            guard let value = UInt32(s, radix: 16) else { return nil }
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >>  8) & 0xFF) / 255
            let b = Double( value        & 0xFF) / 255
            self = Color(red: r, green: g, blue: b)
        case 3:
            guard let value = UInt32(s, radix: 16) else { return nil }
            let r = Double(((value >> 8) & 0xF) * 17) / 255
            let g = Double(((value >> 4) & 0xF) * 17) / 255
            let b = Double(( value       & 0xF) * 17) / 255
            self = Color(red: r, green: g, blue: b)
        default:
            return nil
        }
    }

    /// Deterministic per-project color derived from the project ID.
    /// Uses a Knuth multiplicative hash so colors are stable across process
    /// restarts. Hue bands near red (0±15°) and kimai-green (120±15°) are
    /// skipped to keep project colors visually distinct from state UI.
    private init(projectId id: Int) {
        // Knuth multiplicative hash — stable across runs, unlike Hasher.
        let hash = UInt32(truncatingIfNeeded: UInt64(bitPattern: Int64(id)) &* 2654435761)
        let rawHue = Int(hash % 360)
        let hue = Double(Self.skipForbiddenBands(rawHue)) / 360.0
        self = Color(hue: hue, saturation: 0.55, brightness: 0.62)
    }

    /// Remap a raw hue (0–359) away from the forbidden bands:
    ///   red band:        [345..359] ∪ [0..15]   (31° wide)
    ///   kimai-green band: [105..135]             (31° wide)
    /// Maps an index in [0, 298) onto the two safe intervals:
    ///   [16..104] (89°) then [136..344] (209°).
    static func skipForbiddenBands(_ rawHue: Int) -> Int {
        // Normalise to [0, 298) — the number of safe degrees.
        let idx = ((rawHue % 298) + 298) % 298
        // First safe block: [16, 104] inclusive → 89 values (indices 0..88).
        if idx < 89 { return idx + 16 }
        // Second safe block: [136, 344] inclusive → 209 values (indices 89..297).
        return idx - 89 + 136
    }
}

func formatHoursAndMinutes(_ hours: Double) -> String {
    let total = max(0, Int(hours * 3600))
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}

func formatHoursAndMinutes(seconds: TimeInterval) -> String {
    formatHoursAndMinutes(seconds / 3600)
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
