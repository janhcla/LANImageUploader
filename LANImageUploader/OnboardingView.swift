import SwiftUI
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "OnboardingView")

struct OnboardingView: View {
    @EnvironmentObject var appData: AppData
    @State private var isShowingScanner = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to LAN Image Uploader")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("To get started, you need to pair this app with the companion app running on your Windows server.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Image(systemName: "1.circle.fill")
                    Text("Install and run the companion app on your server.")
                }
                HStack {
                    Image(systemName: "2.circle.fill")
                    Text("Choose a folder where your images will be saved.")
                }
                HStack {
                    Image(systemName: "3.circle.fill")
                    Text("Click the button below to scan the QR code from the companion app.")
                }
            }
            .padding()

            Button(action: {
                self.isShowingScanner = true
            }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Scan QR Code")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .sheet(isPresented: $isShowingScanner) {
            QRCodeScannerView { result in
                handleScan(result: result)
                self.isShowingScanner = false
            }
        }
        .alert("Pairing Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func handleScan(result: String) {
        // We need a struct to decode the JSON
        struct QRCodePayload: Codable {
            let baseURL: String
            let apiKey: String
        }

        guard let data = result.data(using: .utf8) else {
            self.errorMessage = "Could not read QR code data."
            self.showError = true
            return
        }

        do {
            let payload = try JSONDecoder().decode(QRCodePayload.self, from: data)

            // Validate baseURL
            guard let url = URL(string: payload.baseURL), url.scheme == "https" else {
                self.errorMessage = "Invalid Base URL in QR code. It must be a valid HTTPS URL."
                self.showError = true
                return
            }

            appData.settings.baseURL = payload.baseURL
            try appData.saveAPIKey(payload.apiKey)

            // The main view will now update since AppData is an ObservableObject
            // and the root view should be observing it to switch away from onboarding.

        } catch {
            logger.error("Failed to decode QR code payload: \(error)")
            self.errorMessage = "Failed to read QR code. Please make sure you are scanning a valid code from the companion app."
            self.showError = true
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppData())
}
