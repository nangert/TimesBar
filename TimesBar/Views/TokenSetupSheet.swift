import SwiftUI

struct TokenSetupSheet: View {
    @EnvironmentObject var store: TimerStore
    @Environment(\.dismiss) private var dismiss
    @State private var token: String = ""
    @State private var status: Status = .idle
    @State private var isVerifying = false

    enum Status { case idle, success, failure(String) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kimai API token").font(.headline)
            Text("Paste a token from Settings → API access at times.lipsum.services.")
                .font(.caption).foregroundStyle(.secondary)
            SecureField("Token", text: $token)
                .textFieldStyle(.roundedBorder)
            HStack {
                if case let .failure(message) = status {
                    Text(message).font(.caption).foregroundStyle(.red)
                } else if case .success = status {
                    Text("Connected.").font(.caption).foregroundStyle(.green)
                }
                Spacer()
                if store.isAuthenticated {
                    Button("Sign out", role: .destructive) {
                        store.signOut()
                        dismiss()
                    }
                }
                Button("Cancel") { dismiss() }
                Button("Verify & save") {
                    isVerifying = true
                    Task {
                        let ok = await store.authenticate(with: token)
                        isVerifying = false
                        status = ok ? .success : .failure("Token rejected.")
                        if ok { dismiss() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(token.trimmingCharacters(in: .whitespaces).isEmpty || isVerifying)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}
