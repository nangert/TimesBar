import SwiftUI

extension Color {
    /// Matches the green used throughout the Kimai mockup (#3DDC7C).
    static let kimaiGreen = Color(red: 0.24, green: 0.86, blue: 0.49)
    /// Soft red tint for the Stop affordance, against dark/light surfaces.
    static let kimaiStopTint = Color(red: 1.0, green: 0.35, blue: 0.35)
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
