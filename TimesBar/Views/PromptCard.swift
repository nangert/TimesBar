import SwiftUI

/// Card chrome for transient prompts (sleep reconciliation, idle prompt,
/// auto-stop toast): soft fill + hairline stroke on a continuous round rect.
struct PromptCardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
    }
}

extension View {
    func promptCardStyle() -> some View { modifier(PromptCardBackground()) }
}

/// Project dot + title · activity, plus an optional quoted description —
/// the "what's being tracked" summary shared by the sleep and idle prompts.
/// Emits loose rows so the parent VStack's spacing applies between them.
struct TimesheetContextSummary: View {
    let projectTitle: String
    let projectColor: Color
    let activityTitle: String
    let description: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(projectColor)
                .frame(width: 7, height: 7)
            Text(projectTitle)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            Text("·")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(activityTitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        if let description, !description.isEmpty {
            Text("\u{201C}\(description)\u{201D}")
                .font(.system(size: 11))
                .italic()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
