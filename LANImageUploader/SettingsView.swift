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
    @State private var isFirstSetup = true
    @State private var showAutoFillOption = false
    @State private var port: String = ""
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    @State private var showResetConfirmation = false
    @State private var showOfflineSaveSuccess = false
    @State private var isPasswordVisible = false
    @State private var isKeyboardVisible = false

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
        .alert("Credentials Saved", isPresented: $showOfflineSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Credentials saved, will connect when online")
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
                Text("Welcome! Please enter your server details to get started. Your password will be stored securely in the device's Keychain.")
                    .font(.caption)
                    .foregroundStyle(.gray)

                TextField("Server IP (e.g., 192.168.1.10)", text: $serverIP)
                    .textContentType(.URL)
                    .keyboardType(.numbersAndPunctuation)
                    .autocapitalization(.none)

                TextField("Share Name (e.g., MediaCaptureShare)", text: $shareName)
                    .autocapitalization(.none)

                TextField("Target Directory (e.g., MediaCapture)", text: $targetDirectory)
                    .autocapitalization(.none)

                TextField("Username (e.g., WORKGROUP\\user)", text: $username)
                    .textContentType(.username)

                ZStack(alignment: .trailing) {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }

                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }

                TextField("Port (optional)", text: $port)
                    .keyboardType(.numberPad)
            }
            Section {
                Button("Save") {
                    Task { await saveSettingsOffline() }
                }
                .disabled(!canSave)
                .foregroundStyle(canSave ? .green : .gray)

                Button("Reset", role: .destructive) {
                    showResetConfirmation = true
                }
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
                ZStack(alignment: .trailing) {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    }

                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                    }
                }
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
                Button("Re-configure (First Time Setup)") {
                    isFirstSetup = true
                }
                .foregroundStyle(.blue)
            }
        }
    }


    func saveSettingsOffline() async {
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

        // Save settings without network test
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
                showOfflineSaveSuccess = true
                isFirstSetup = false
                showAutoFillOption = false
            } catch {
                showError = true
                errorMessage = "Failed to save password: \(error.localizedDescription)"
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

    func discardChanges() {
        loadSettings()
    }

    func resetSettings() {
        serverIP = ""
        shareName = ""
        targetDirectory = ""
        username = ""
        password = ""
        port = ""
        showAutoFillOption = true
        
        appData.settings = ServerSettings(serverIP: "", shareName: "", targetDirectory: nil, username: "", port: nil)
        try? appData.savePassword("")
        
        isFirstSetup = true
    }
}

// Rest of the file (Publishers extension, View extension, Preview) remains the same...
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
