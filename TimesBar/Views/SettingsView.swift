import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TimerStore
    @ObservedObject private var prefs = UserPreferences.shared

    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var urlText: String = ""
    @State private var urlError: String?
    @State private var isSavingURL = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TokenSetupForm(
                onCancel: onCancel,
                onSaved: onSaved
            )

            Divider()

            serverSection
        }
        .onAppear {
            urlText = prefs.baseURL.absoluteString
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(text: "Server")

            FormRow(label: "Base URL") {
                TextField("https://your-kimai-instance.example.com", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .pillFieldStyle()
                    .onSubmit(saveURL)
                    .onChange(of: urlText) { _, _ in
                        urlError = nil
                    }
            }

            if let urlError {
                Text(urlError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button(action: saveURL) {
                    Label(isSavingURL ? "Saving…" : "Save URL",
                          systemImage: "checkmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || isSavingURL)
            }
        }
    }

    private func saveURL() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSavingURL else { return }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              (scheme == "https" || scheme == "http"),
              url.host != nil else {
            urlError = "Enter a valid URL starting with https:// or http://"
            return
        }

        isSavingURL = true
        prefs.baseURL = url
        Task {
            await store.rebuildClient()
            isSavingURL = false
            onSaved()
        }
    }
}
