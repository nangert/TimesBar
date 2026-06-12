import SwiftUI

/// 4pt progress strip shared by the Today row and the vacation card.
/// Capsule caps, animated width changes, and an optional brighter gradient
/// once the value passes 100% so "target reached" reads at a glance.
struct ThinProgressBar: View {
    /// Fraction in [0, ∞) — values above 1 render full-width in the over style.
    let progress: Double
    var tint: Color = .kimaiGreen
    /// Opt-in: switch the fill to a gradient when progress ≥ 1. The Today bar
    /// wants this ("over target" is a state worth signalling); the vacation
    /// card does not (an exhausted budget is not a celebration).
    var showsOverState: Bool = false

    /// 0/0 targets (e.g. hours_per_week preference set to 0) yield NaN.
    private var normalized: Double {
        progress.isFinite ? min(max(progress, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(fill)
                    // 4pt floor keeps a visible dot once there is any progress.
                    .frame(width: normalized > 0
                           ? max(geo.size.width * CGFloat(normalized), 4)
                           : 0)
            }
            .animation(.easeOut(duration: 0.35), value: normalized)
        }
        .frame(height: 4)
    }

    private var fill: AnyShapeStyle {
        if showsOverState, progress.isFinite, progress >= 1 {
            return AnyShapeStyle(
                LinearGradient(colors: [tint, .mint],
                               startPoint: .leading, endPoint: .trailing))
        }
        return AnyShapeStyle(tint)
    }
}
