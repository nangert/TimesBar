import SwiftUI

/// Pill-shaped input/menu styling used across inline forms.
struct PillFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.08))
            )
    }
}

extension View {
    func pillFieldStyle() -> some View { modifier(PillFieldBackground()) }
}

/// Row with a fixed-width label and a trailing input — used in the inline forms.
struct FormRow<Trailing: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            trailing()
        }
    }
}

/// Menu-backed picker that looks like the pill inputs.
struct InlinePicker: View {
    let placeholder: LocalizedStringKey
    let selectionTitle: String?
    let options: [(Int, String)]
    let onPick: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(options, id: \.0) { id, title in
                Button(title) { onPick(id) }
            }
        } label: {
            HStack {
                Group {
                    if let selectionTitle {
                        Text(selectionTitle)
                            .foregroundStyle(.primary)
                    } else {
                        Text(placeholder)
                            .foregroundStyle(.secondary)
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            .pillFieldStyle()
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }
}
