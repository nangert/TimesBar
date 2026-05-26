import SwiftUI

struct SectionHeader: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .textCase(.uppercase)
            .tracking(1.2)
            .foregroundStyle(.secondary)
    }
}
