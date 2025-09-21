//
//  SettingsView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
import AMSMB2
import Combine
import UIKit

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
    @State private var isDiscovering = false
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
                if isDiscovering {
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
                
                Text("Enter your credentials and target folder. Then choose 'Auto-Fill' to detect your SMB server automatically, or select 'Try Direct IP' if you already know the server's IP address. Note: Sometimes 'Auto-Fill' cannot exctract the server info automatically. This app stores your password in a secure keychain.")
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
                .disabled(!canAutoFill || isDiscovering)
                .foregroundStyle(canAutoFill && !isDiscovering ? .blue : .gray)
                
                Button("Try Direct IP") {
                    showDirectIPPrompt = true
                }
                .disabled(!canAutoFill || isDiscovering)
                .foregroundStyle(canAutoFill && !isDiscovering ? .blue : .gray)
                
                Button("Switch to Manual Setup") {
                    isFirstSetup = false
                }
                .foregroundStyle(.blue)
                .disabled(isDiscovering)
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

    private func startAutoFill() async {
        isDiscovering = true
        searchProgress = "Checking network connection..."
        
        defer {
            Task { @MainActor in
                isDiscovering = false
            }
        }
        
        do {
            let portNumber = Int(port)
            searchProgress = "Searching for SMB servers..."
            
            let trimmedIP = serverIP.trimmingCharacters(in: .whitespacesAndNewlines)
            let info = try await NetworkDiscovery.shared.retrieveNetworkInfo(
                targetFolder: targetDirectory,
                username: username,
                password: password,
                directIP: trimmedIP.isEmpty ? nil : trimmedIP,
                port: portNumber
            )
            
            await MainActor.run {
                tempNetworkInfo = info
                showAutoFillConfirmation = true
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "Failed to retrieve network info: \(error.localizedDescription)"
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

    // MARK: - Improved Validation and Error Mapping
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

        // Normalize target directory (relative to the share)
        let normalizedTargetDir: String? = {
            let trimmed = targetDirectory.trimmingCharacters(in: .init(charactersIn: "/\\"))
            guard !trimmed.isEmpty else { return nil }
            let lowerShare = shareName.lowercased()
            var path = trimmed
            if path.lowercased() == lowerShare {
                return nil
            }
            if path.lowercased().hasPrefix(lowerShare + "/") {
                path = String(path.dropFirst(lowerShare.count + 1))
            }
            return path.isEmpty ? nil : path
        }()

        // Test SMB connection
        do {
            var components = URLComponents()
            components.scheme = "smb"
            components.host = serverIP
            if let p = portNumber { components.port = p }
            guard let serverURL = components.url else {
                throw NSError(domain: "SMBError", code: -10, userInfo: [NSLocalizedDescriptionKey: "Invalid server URL"])
            }

            guard let client = SMB2Manager(
                url: serverURL,
                credential: URLCredential(user: username, password: password, persistence: .forSession)
            ) else {
                throw NSError(domain: "SMBError", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create SMB client."])
            }

            // Step 1: Connect to the share
            do {
                try await client.connectShare(name: shareName)
            } catch {
                let mapped = mapSMBError(error, context: "Could not open share '\(shareName)'.")
                throw mapped
            }

            // Step 2: If a subdirectory is specified, try to list it to confirm it exists
            if let dir = normalizedTargetDir {
                do {
                    _ = try await client.contentsOfDirectory(atPath: dir)
                } catch {
                    let mapped = mapSMBError(error, context: "Could not access folder '\(dir)' inside share '\(shareName)'.")
                    try? await client.disconnectShare()
                    throw mapped
                }
            }

            // Step 3: Disconnect
            try await client.disconnectShare()

            // Save settings if validation passes
            await MainActor.run {
                appData.settings = ServerSettings(
                    serverIP: serverIP,
                    shareName: shareName,
                    targetDirectory: normalizedTargetDir,
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
                if let nsError = error as NSError? {
                    validationErrorMessage = friendlyMessage(for: nsError)
                } else {
                    validationErrorMessage = "Invalid settings: \(error.localizedDescription)"
                }
            }
        }
    }

    // Map AMSMB2 and POSIX errors to user-friendly text
    private func friendlyMessage(for error: NSError) -> String {
        if error.domain == "AMSMB2ErrorDomain" {
            let status = String(format: "0x%08X", error.code)
            switch error.code {
            case 0xC0000022:
                return "Access denied: The account may not have permission to open this share or list the folder. Please recheck the username/password and permissions."
            case 0xC000006D, 0xC000006A:
                return "Authentication failed: Please verify the username and password."
            case 0xC0000034, 0x00000002:
                return "The specified folder was not found on the server."
            case 0xC0000103:
                return "The specified path exists but is not a directory."
            default:
                return "Server error (\(status)): \(error.localizedDescription)"
            }
        }
        if error.domain == NSPOSIXErrorDomain {
            let code32 = Int32(error.code)
            switch code32 {
            case EPERM:
                return "Operation not permitted by the server. Ensure the account can access the share and list contents."
            case ENOENT:
                return "The specified folder does not exist on the server."
            case EACCES:
                return "Permission denied. Check that your user has access to this share/folder."
            default:
                return "System error (POSIX \(error.code)): \(error.localizedDescription)"
            }
        }
        return "Invalid settings: \(error.localizedDescription) (Domain: \(error.domain), Code: \(error.code))"
    }

    private func mapSMBError(_ error: Error, context: String) -> NSError {
        let ns = error as NSError
        var userInfo = ns.userInfo
        let base = userInfo[NSLocalizedDescriptionKey] as? String ?? ns.localizedDescription
        userInfo[NSLocalizedDescriptionKey] = "\(context) \(base)"
        return NSError(domain: ns.domain, code: ns.code, userInfo: userInfo)
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
