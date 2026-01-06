//
//  SettingsView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
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
    @State private var showWarning = false
    @State private var isFirstSetup = true
    @State private var showAutoFillOption = false
    @State private var port: String = ""
    @State private var isDiscovering = false
    @State private var searchProgress = "Initializing..."
    @State private var showAutoFillConfirmation = false
    @State private var tempNetworkInfo: NetworkInfo?
    @State private var showResetConfirmation = false
    @State private var showDirectIPPrompt = false
    @State private var isKeyboardVisible = false
    @State private var directIPInput = ""
    @State private var discoveryTask: Task<Void, Never>? = nil
    @State private var activeSheet: SettingsSheet? = nil

    private enum SettingsSheet: Identifiable {
        case helpGuide
        case discovery

        var id: Int {
            switch self {
            case .helpGuide: return 0
            case .discovery: return 1
            }
        }
    }

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
                Button("Help") { activeSheet = .helpGuide }
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
                    startAutoFill()
                }
                directIPInput = ""
            }
        } message: {
            Text("Enter the IP address of your SMB server.\n\nYou can typically find this in your router's connected devices list or by checking the server's network settings.")
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .helpGuide:
                HelpGuideView()
            case .discovery:
                DiscoveryResultsView(
                    username: username,
                    password: password,
                    port: Int(port),
                    onSelect: { info in
                        serverIP = info.serverIP
                        shareName = info.shareName
                        isFirstSetup = false
                        showSuccess = true
                    }
                )
                .environmentObject(appData)
            }
        }
    }

    var firstSetupView: some View {
        Group {
            Section("First Setup") {
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
                if isDiscovering {
                    HStack(spacing: 15) {
                        ProgressView()
                            .controlSize(.small)
                        Text(searchProgress)
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Spacer()
                        Button("Cancel") {
                            stopAutoFill()
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }

                Button("Browse Network for Servers") {
                    activeSheet = .discovery
                }
                .disabled(!canAutoFill)
                .foregroundStyle(canAutoFill ? .blue : .gray)
                
                Button("Try Direct IP") {
                    showDirectIPPrompt = true
                }
                .disabled(!canAutoFill || isDiscovering)
                .foregroundStyle(canAutoFill && !isDiscovering ? .blue : .gray)
                
                Button("Switch to Manual Setup") {
                    stopAutoFill()
                    isFirstSetup = false
                }
                .foregroundStyle(.blue)
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
                if isDiscovering {
                    HStack(spacing: 15) {
                        ProgressView()
                            .controlSize(.small)
                        Text(searchProgress)
                            .foregroundStyle(.blue)
                            .font(.caption)
                        Spacer()
                        Button("Cancel") {
                            stopAutoFill()
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 4)
                }
                
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

    private func stopAutoFill() {
        discoveryTask?.cancel()
        discoveryTask = nil
        isDiscovering = false
        searchProgress = "Ready"
    }

    private func startAutoFill() {
        discoveryTask?.cancel()
        discoveryTask = Task {
            await performAutoFill()
        }
    }

    private func performAutoFill() async {
        isDiscovering = true
        searchProgress = "Checking network connection..."
        
        defer {
            Task { @MainActor in
                isDiscovering = false
                discoveryTask = nil
            }
        }
        
        do {
            let portNumber = Int(port)
            searchProgress = "Searching for SMB servers..."
            
            let trimmedIP = serverIP.trimmingCharacters(in: .whitespacesAndNewlines)
            let info = try await appData.discoveryService.retrieveNetworkInfo(
                targetFolder: targetDirectory,
                username: username,
                password: password,
                directIP: trimmedIP.isEmpty ? nil : trimmedIP,
                port: portNumber,
                onStatus: { status in
                    Task { @MainActor in
                        guard !Task.isCancelled else { return }
                        appData.connectionStatus = status
                        switch status {
                        case .discovery(let state):
                            switch state {
                            case .subnetScan(let progress):
                                searchProgress = "Scanning subnet (\(Int(progress * 100))%)..."
                            case .bonjourSearch:
                                searchProgress = "Searching via Bonjour..."
                            case .resolving(let name):
                                searchProgress = "Resolving \(name)..."
                            }
                        case .connecting(let host):
                            searchProgress = "Connecting to \(host)..."
                        case .authenticating:
                            searchProgress = "Authenticating..."
                        case .connected:
                            searchProgress = "Connected!"
                        case .failure(let error):
                            searchProgress = "Error: \(error.localizedDescription)"
                        case .disconnected:
                            searchProgress = "Ready"
                        }
                    }
                }
            )
            
            if Task.isCancelled { return }
            
            await MainActor.run {
                tempNetworkInfo = info
                showAutoFillConfirmation = true
            }
        } catch is CancellationError {
            // Cancelled
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    showError = true
                    errorMessage = "Failed to retrieve network info: \(error.localizedDescription)"
                }
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

        // Convert optional port to an Int if possible (silently drop invalid input)
        let portNumber = Int(port)

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

        await MainActor.run {
            appData.settings = ServerSettings(
                serverIP: serverIP,
                shareName: shareName,
                targetDirectory: normalizedTargetDir,
                username: username,
                port: portNumber
            )
        }

        do {
            try appData.savePassword(password)
            await MainActor.run {
                showSuccess = true
                isFirstSetup = false
                showAutoFillOption = false
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "Failed to save password: \(error.localizedDescription)"
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
