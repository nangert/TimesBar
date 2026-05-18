import SwiftUI

struct Sparkline: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let maxValue = max(values.max() ?? 0, 0.0001)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(height: max(2, geo.size.height * CGFloat(value / maxValue)))
                }
            }
        }
    }
}

#Preview {
    Sparkline(values: [1, 2, 0, 3.5, 4, 1.2, 0])
        .frame(width: 60, height: 16)
        .padding()
}
