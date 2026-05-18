import SwiftUI
import AppKit

struct FooterRow: View {
    let onSettings: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onSettings) {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 12))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                if let url = URL(string: "https://times.lipsum.services") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Open web")
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Menu {
                Button("Sign out", role: .destructive, action: onSignOut)
                Divider()
                Button("Quit TimesBar") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
