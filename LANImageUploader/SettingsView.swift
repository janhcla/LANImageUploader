import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var showDisconnectConfirmation = false
    @State private var disconnectError: Error?

    var body: some View {
        Form {
            Section("Connection Status") {
                if appData.isConfigured {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Connected to \(appData.settings.baseURL)")
                    }
                } else {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                        Text("Not Connected")
                    }
                }
            }

            Section {
                Button("Disconnect", role: .destructive) {
                    showDisconnectConfirmation = true
                }
                .disabled(!appData.isConfigured)
            }
        }
        .navigationTitle("Settings")
        .alert("Disconnect?", isPresented: $showDisconnectConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                disconnect()
            }
        } message: {
            Text("Are you sure you want to disconnect from the server? You will need to scan the QR code again to reconnect.")
        }
        .alert("Error", isPresented: Binding(
            get: { disconnectError != nil },
            set: { if !$0 { disconnectError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(disconnectError?.localizedDescription ?? "Unknown error")
        }
    }

    private func disconnect() {
        let appData = self.appData
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try appData.saveAPIKey("")
                }.value
                self.appData.settings.baseURL = ""
            } catch {
                self.disconnectError = error
            }
        }
    }
}

#Preview {
    // For previewing different states
    let configuredAppData = AppData()
    configuredAppData.settings.baseURL = "https://my-server.local:1234"
    // You would need a way to inject a dummy API key for this preview to be fully accurate

    return SettingsView()
        .environmentObject(configuredAppData)
}
