//
//  SettingsView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
import AMSMB2

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var serverIP = ""
    @State private var shareName = ""
    @State private var targetDirectory = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showHelpGuide = false
    @State private var showWarning = false
    @State private var isFirstSetup = true  // Default to First Setup after reinstall
    @State private var showAutoFillOption = false
    @State private var port: String = ""
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    @State private var isSearching = false
    @State private var searchProgress = "Initializing..."
    @State private var showAutoFillConfirmation = false
    @State private var tempNetworkInfo: NetworkInfo?
    @State private var showResetConfirmation = false
    @State private var showDirectIPPrompt = false
    @State private var isKeyboardVisible = false
    @State private var directIPInput = ""

    var isSetupComplete: Bool {
        !appData.settings.serverIP.isEmpty && !appData.settings.shareName.isEmpty &&
        !appData.settings.username.isEmpty && appData.getPassword() != nil
    }

    var canAutoFill: Bool {
        !username.isEmpty && !password.isEmpty && !targetDirectory.isEmpty
    }

    var canSave: Bool {
        !serverIP.isEmpty && !shareName.isEmpty && !username.isEmpty && !password.isEmpty
    }

    var hasUnsavedChanges: Bool {
        serverIP != appData.settings.serverIP ||
        shareName != appData.settings.shareName ||
        targetDirectory != (appData.settings.targetDirectory ?? "") ||
        username != appData.settings.username ||
        port != (appData.settings.port.map(String.init) ?? "") ||
        password != (appData.getPassword() ?? "")
    }

    var body: some View {
        Form {
            if isFirstSetup {
                firstSetupView
            } else {
                completeSetupView
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Help") { showHelpGuide = true }
            }
        }
        .onAppear(perform: loadSettings)
        .alert("Settings Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Settings Saved", isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your settings have been saved successfully.")
        }
        .alert("Empty Settings", isPresented: $showWarning) {
            Button("Stay", role: .cancel) {}
            Button("Leave Anyway") { /* Navigation handled by SwiftUI */ }
        } message: {
            Text("Leaving with empty settings will prevent uploads from working.")
        }
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationErrorMessage)
        }
        .alert("Reset Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetSettings() }
        } message: {
            Text("Are you sure you want to delete these settings? This action cannot be undone.")
        }
        .alert("Enter Direct IP", isPresented: $showDirectIPPrompt) {
            TextField("Server IP Address (e.g., 192.168.1.10)", text: $directIPInput)
                .keyboardType(.numbersAndPunctuation)
            Button("Cancel", role: .cancel) {
                directIPInput = ""
            }
            Button("Connect") {
                if !directIPInput.isEmpty {
                    serverIP = directIPInput
                    Task { await startAutoFill() }
                }
                directIPInput = ""
            }
        } message: {
            Text("Enter the IP address of your SMB server.\n\nYou can typically find this in your router's connected devices list or by checking the server's network settings.")
        }
        .sheet(isPresented: $showHelpGuide) {
            HelpGuideView()
        }
        .onReceive(Publishers.keyboardVisibility) { isVisible in
            isKeyboardVisible = isVisible
        }
        .navigationBarBackButtonHidden(showWarning)
        .onChange(of: isFirstSetup) { _, _ in showAutoFillOption = false }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                VStack(spacing: 4) {
                    if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        Text("Version \(appVersion) (\(buildNumber))")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                    Text("(c) Jan H. Clausen, Midtbylægerne")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
        }
    }

    var firstSetupView: some View {
        Group {
            Section("First Setup") {
                if isSearching {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(searchProgress)
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Text("Enter your credentials and target folder. Then choose 'Auto-Fill' to detect your SMB server automatically, or select 'Try Direct IP' if you already know the server’s IP address. Note: Sometimes 'Auto-Fill' cannot exctract the server info automatically. This app stores your password in a secure keychain.")
                    .font(.caption)
                    .foregroundStyle(.gray)
                TextField("Target Directory (e.g., MediaCapture)", text: $targetDirectory)
                    .autocapitalization(.none)
                TextField("Username (e.g., WORKGROUP\\user)", text: $username)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                TextField("Port (optional)", text: $port)
                    .keyboardType(.numberPad)
            }
            Section {
                Button("Auto-Fill Network Info") {
                    Task { await startAutoFill() }
                }
                .disabled(!canAutoFill || isSearching)
                .foregroundStyle(canAutoFill && !isSearching ? .blue : .gray)
                
                Button("Try Direct IP") {
                    showDirectIPPrompt = true
                }
                .disabled(!canAutoFill || isSearching)
                .foregroundStyle(canAutoFill && !isSearching ? .blue : .gray)
                
                Button("Switch to Manual Setup") {
                    isFirstSetup = false
                }
                .foregroundStyle(.blue)
                .disabled(isSearching)
            }
        }
        .alert("Confirm Auto-Fill", isPresented: $showAutoFillConfirmation) {
            Button("Cancel", role: .cancel) {
                tempNetworkInfo = nil
            }
            Button(appData.settings.serverIP.isEmpty ? "Save" : "Overwrite") {
                if let info = tempNetworkInfo {
                    serverIP = info.serverIP
                    shareName = info.shareName
                    targetDirectory = info.targetDirectory ?? ""
                    isFirstSetup = false
                    tempNetworkInfo = nil
                    showSuccess = true
                }
            }
        } message: {
            if let info = tempNetworkInfo {
                Text("Network information found:\nServer: \(info.serverIP)\nShare: \(info.shareName)\(info.targetDirectory != nil ? "\nDirectory: \(info.targetDirectory!)" : "")\n\nDo you want to use this configuration?")
            }
        }
    }

    var completeSetupView: some View {
        Group {
            Section("Server Configuration") {
                TextField("Server IP (e.g., 192.168.1.10)", text: $serverIP)
                    .textContentType(.URL)
                    .keyboardType(.numbersAndPunctuation)
                    .autocapitalization(.none)
                TextField("Share Name (e.g., MediaCaptureShare)", text: $shareName)
                    .autocapitalization(.none)
                TextField("", text: $targetDirectory)
                    .autocapitalization(.none)
                    .placeholder(when: targetDirectory.isEmpty) {
                        Text("Optional - Target Directory (e.g., Data/MediaCapture)")
                            .foregroundStyle(.gray)
                    }
                TextField("", text: $port)
                    .keyboardType(.numberPad)
                    .placeholder(when: port.isEmpty) {
                        Text("Port (optional) - Leave empty for default SMB ports")
                            .foregroundStyle(.gray)
                    }
                TextField("Username (e.g., WORKGROUP\\user)", text: $username)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            Section {
                Button("Save") {
                    Task { await saveSettings() }
                }
                .disabled(!canSave)
                .foregroundStyle(canSave ? .green : .gray)
                Button("Discard", role: .destructive) { discardChanges() }
                .disabled(!hasUnsavedChanges)
                .foregroundStyle(hasUnsavedChanges ? .red : .gray)
                Button("Reset", role: .destructive) { showResetConfirmation = true }
                Button("Switch to Auto-Fill Setup") {
                    isFirstSetup = true
                }
                .foregroundStyle(.blue)
            }
        }
    }

    func loadSettings() {
        serverIP = appData.settings.serverIP
        shareName = appData.settings.shareName
        targetDirectory = appData.settings.targetDirectory ?? ""
        username = appData.settings.username
        port = appData.settings.port.map(String.init) ?? ""
        password = appData.getPassword() ?? ""
        // Only set isFirstSetup if settings are truly empty on first load
        if !isSetupComplete && (serverIP.isEmpty && shareName.isEmpty && username.isEmpty && password.isEmpty) {
            isFirstSetup = true
        }
    }

    func saveSettings() async {
        guard canSave else {
            showError = true
            errorMessage = "All required fields must be filled to save."
            return
        }

        // Validate IP address
        let ipComponents = serverIP.split(separator: ".")
        guard ipComponents.count == 4, ipComponents.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
            showError = true
            errorMessage = "Please enter a valid IP address (e.g., 192.168.1.10)"
            return
        }

        // Validate port if provided
        let portNumber: Int?
        if !port.isEmpty {
            guard let number = Int(port), number > 0, number <= 65535 else {
                showError = true
                errorMessage = "Please enter a valid port number (1-65535)"
                return
            }
            portNumber = number
        } else {
            portNumber = nil
        }

        let trimmedTargetDirectory = targetDirectory.trimmingCharacters(in: .init(charactersIn: "/\\"))
        let targetDir: String? = trimmedTargetDirectory.isEmpty ? nil : trimmedTargetDirectory

        // Test SMB connection
        do {
            guard let client = SMB2Manager(
                url: URL(string: "smb://\(serverIP)")!,
                credential: URLCredential(user: username, password: password, persistence: .forSession)
            ) else {
                throw NSError(domain: "SMBError", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create SMB client."])
            }

            try await client.connectShare(name: shareName)
            if let dir = targetDir, !dir.isEmpty {
                    _ = try await client.contentsOfDirectory(atPath: dir)
            }
            try await client.disconnectShare()

            // Save settings if validation passes
            await MainActor.run {
                appData.settings = ServerSettings(
                    serverIP: serverIP,
                    shareName: shareName,
                    targetDirectory: targetDir,
                    username: username,
                    port: portNumber
                )
                do {
                    try appData.savePassword(password)
                    showSuccess = true
                    isFirstSetup = false
                    showAutoFillOption = false
                } catch {
                    showError = true
                    errorMessage = "Failed to save password: \(error.localizedDescription)"
                }
            }
        } catch {
            await MainActor.run {
                showValidationError = true
                validationErrorMessage = "Invalid settings: \(error.localizedDescription)"
            }
        }
    }

    private func startAutoFill() async {
        isSearching = true
        searchProgress = "Checking network connection..."
        
        // Function to update progress on main thread
    func updateProgress(_ message: String) {
        Task { @MainActor in
            searchProgress = message
        }
    }
    
    // Check if we have a direct IP
    let portNumber = Int(port)
            
            if !serverIP.isEmpty {
                // Try direct connection with provided IP
                updateProgress("Trying direct connection to \(serverIP)...")
                
                do {
                    let info = try await retrieveNetworkInfo(
                        targetFolder: targetDirectory,
                        username: username,
                        password: password,
                        directIP: serverIP,
                        port: portNumber
                    )
                    
                    await MainActor.run {
                        tempNetworkInfo = info
                        showAutoFillConfirmation = true
                        isSearching = false
                    }
                    return
                } catch {
                    updateProgress("Direct IP failed: \(error.localizedDescription)")
                    
                    // Display error after a short delay and stop searching
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await MainActor.run {
                        showError = true
                        errorMessage = "Failed to connect to server at \(serverIP): \(error.localizedDescription)\n\nPlease verify the IP address and credentials."
                        isSearching = false
                    }
                    return
                }
            } else {
                // Try common IP addresses
                updateProgress("Attempting to find server on network...")

                do {
                    let info = try await retrieveNetworkInfo(
                        targetFolder: targetDirectory,
                        username: username,
                        password: password,
                        directIP: nil,
                        port: portNumber
                    )
                    
                    await MainActor.run {
                        tempNetworkInfo = info
                        showAutoFillConfirmation = true
                        isSearching = false
                    }
                } catch {
                    // Handle thrown error here
                    updateProgress("Failed to find server automatically: \(error.localizedDescription)")
                    
                    // Show an alert or set an error message
                    await MainActor.run {
                        showError = true
                        errorMessage = """
                            Failed to find server automatically: \(error.localizedDescription)

                            Please try using 'Try Direct IP' to manually enter your server's IP address.
                            """
                        isSearching = false
                    }
                }
            }
}

    func discardChanges() {
        loadSettings()
    }

    func resetSettings() {
        // Clear all fields
        serverIP = ""
        shareName = ""
        targetDirectory = ""
        username = ""
        password = ""
        port = ""
        showAutoFillOption = true
        
        // Clear AppData settings
        appData.settings = ServerSettings(serverIP: "", shareName: "", targetDirectory: nil, username: "", port: nil)
        try? appData.savePassword("") // Clear saved password
        
        // Reset to first setup view
        isFirstSetup = true
    }
}

import Combine
import UIKit

extension Publishers {
    static var keyboardVisibility: AnyPublisher<Bool, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { _ in true }
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ in false }

        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppData())
}
