import SwiftUI

struct TokenSetupSheet: View {
    @EnvironmentObject var store: TimerStore
    @Environment(\.dismiss) private var dismiss
    @State private var token: String = ""
    @State private var status: Status = .idle
    @State private var isVerifying = false

    enum Status: Equatable { case idle, success, failure(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kimai API token")
                    .font(.system(size: 14, weight: .semibold))
                Text("Paste a token from Settings → API access at times.lipsum.services.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

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
                    Button("Sign out", role: .destructive) {
                        store.signOut()
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.system(size: 12))
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
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
        .padding(18)
        .frame(width: 380)
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
            if ok { dismiss() }
        }
    }
}
