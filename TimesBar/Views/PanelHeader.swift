import SwiftUI

/// Standard ✕ dismiss control used by the dropdown panel headers.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(2)
        }
        .buttonStyle(.plain)
        .help("Close")
    }
}

/// Section header + optional trailing ✕ — the standard first row of a
/// dropdown panel.
struct PanelHeader: View {
    let title: String
    var onClose: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader(text: title)
            Spacer()
            if let onClose {
                CloseButton(action: onClose)
            }
        }
    }
}
