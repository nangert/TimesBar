import SwiftUI

struct TokenSetupForm: View {
    @EnvironmentObject var store: TimerStore
    @ObservedObject private var prefs = UserPreferences.shared
    /// `nil` when the user is not yet authenticated — there's nothing to cancel back to.
    let onCancel: (() -> Void)?
    let onSaved: () -> Void

    @State private var token: String = ""
    @State private var isVerifying = false
    @State private var status: Status = .idle

    enum Status: Equatable { case idle, success, failure(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelHeader(title: store.isAuthenticated ? "Settings" : "Sign in",
                        onClose: onCancel)

            Text(store.isAuthenticated
                 ? "Replace the saved Kimai API token, or sign out."
                 : "Paste a Kimai API token from Settings → API access at \(prefs.baseURL.host ?? "your Kimai instance").")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            FormRow(label: "Token") {
                SecureField("paste here", text: $token)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .pillFieldStyle()
                    .onSubmit(verify)
            }

            statusLine

            HStack(spacing: 8) {
                if store.isAuthenticated {
                    Button(role: .destructive) {
                        store.signOut()
                        token = ""
                        status = .idle
                    } label: {
                        Text("Sign out")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                Spacer()
                Button(action: verify) {
                    Label(isVerifying ? "Verifying…" : "Verify & save",
                          systemImage: "checkmark.shield")
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .tint(.kimaiGreen)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
            }
        }
    }

    @ViewBuilder private var statusLine: some View {
        switch status {
        case .idle:
            EmptyView()
        case .success:
            Label("Connected.", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func verify() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isVerifying else { return }
        isVerifying = true
        Task {
            let ok = await store.authenticate(with: trimmed)
            isVerifying = false
            status = ok ? .success : .failure("Token rejected by Kimai.")
            if ok {
                token = ""
                onSaved()
            }
        }
    }
}
