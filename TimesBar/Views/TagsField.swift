import SwiftUI

// MARK: - Tag-normalization helpers (non-SwiftUI, unit-testable)

/// Normalise a raw user-typed value into zero or more tag strings.
/// Splits on commas, trims whitespace, and deduplicates against `existing`.
///
/// Kept as a free function so unit tests can call it without importing SwiftUI
/// or triggering property-wrapper initializers.
func normalizeTags(_ raw: String, existing: [String]) -> [String] {
    raw.split(separator: ",", omittingEmptySubsequences: true)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !existing.contains($0) }
}

// MARK: -

/// Chip-style multi-select field for Kimai tags.
///
/// Selected tags render as pill chips with an × to remove. A text input below
/// the chips lets the user type a new tag; pressing Return or comma adds it.
/// A dropdown filtered by the current input text shows known tags as suggestions.
struct TagsField: View {
    @Binding var tags: [String]
    /// Pool of tag names to suggest (from `TimerStore.knownTags`).
    let suggestions: [String]

    @State private var input: String = ""
    @State private var showDropdown: Bool = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            chipsArea
            if showDropdown && !filteredSuggestions.isEmpty {
                dropdownList
            }
        }
    }

    // MARK: - Sub-views

    private var chipsArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(label: tag) { removeTag(tag) }
                    }
                }
            }
            TextField(tags.isEmpty ? "Add tag…" : "Add another…", text: $input)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($inputFocused)
                .onSubmit { commitInput() }
                .onChange(of: input) { _, newValue in
                    // Treat a trailing comma as "add now" so keyboard-heavy users
                    // can type "foo,bar," without reaching for Return.
                    if newValue.hasSuffix(",") {
                        input = String(newValue.dropLast())
                        commitInput()
                    } else {
                        showDropdown = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                    }
                }
                .onChange(of: inputFocused) { _, focused in
                    if !focused { showDropdown = false }
                }
        }
        .pillFieldStyle()
    }

    private var dropdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(filteredSuggestions, id: \.self) { tag in
                Button(action: { pickSuggestion(tag) }) {
                    Text(tag)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .onHover { hovering in
                    // highlight is handled by the button's default hover
                    _ = hovering
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .zIndex(10)
    }

    // MARK: - Helpers

    private var filteredSuggestions: [String] {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return suggestions
            .filter { $0.lowercased().contains(trimmed) && !tags.contains($0) }
            .prefix(6)
            .map { $0 }
    }

    private func commitInput() {
        let newTags = normalizeTags(input, existing: tags)
        tags.append(contentsOf: newTags)
        input = ""
        showDropdown = false
    }

    private func addTag(_ raw: String) {
        let newTags = normalizeTags(raw, existing: tags)
        tags.append(contentsOf: newTags)
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    private func pickSuggestion(_ tag: String) {
        // suggestions are already clean strings — add directly without re-splitting
        if !tags.contains(tag) { tags.append(tag) }
        input = ""
        showDropdown = false
        inputFocused = true
    }
}

// MARK: - TagChip

/// A single removable tag pill.
struct TagChip: View {
    let label: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 14, height: 14)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(
            Capsule().fill(Color.primary.opacity(0.1))
        )
        .fixedSize()
    }
}

// MARK: - FlowLayout

/// Wraps children left-to-right, breaking to a new line when they overflow.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            _ = maxWidth // suppress warning
        }
    }
}
