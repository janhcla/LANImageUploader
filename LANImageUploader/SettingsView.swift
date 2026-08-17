//
//  SettingsView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct SMBConnectionTarget: Equatable {
    let shareName: String
    let targetDirectory: String?

    /// The legacy SMB validator accepts one share-relative target path. Keeping
    /// this conversion here lets the direct connection test use the same
    /// resolution path as the established setup flow.
    var validationTargetFolder: String {
        guard let targetDirectory, !targetDirectory.isEmpty else {
            return shareName
        }
        return "\(shareName)/\(targetDirectory)"
    }

    init?(shareName: String, targetDirectory: String) {
        let normalizedShare = shareName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedShare.isEmpty else { return nil }

        var normalizedDirectory = targetDirectory
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/\\\\"))
        let lowerShare = normalizedShare.lowercased()
        if normalizedDirectory.lowercased() == lowerShare {
            normalizedDirectory = ""
        } else if normalizedDirectory.lowercased().hasPrefix(lowerShare + "/") {
            normalizedDirectory = String(normalizedDirectory.dropFirst(normalizedShare.count + 1))
        }

        self.shareName = normalizedShare
        self.targetDirectory = normalizedDirectory.isEmpty ? nil : normalizedDirectory
    }
}

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @AppStorage(Constants.UserDefaults.ocrMode) private var ocrModeRawValue: String = OCRMode.full.rawValue
    @State private var serverIP = ""
    @State private var shareName = ""
    @State private var targetDirectory = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successTitle = "Settings Saved"
    @State private var successMessage = ""
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
    @State private var directIPInput = ""
    @State private var discoveryTask: Task<Void, Never>? = nil
    @State private var activeDiscoveryOperationID: UUID?
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
        ServerConnectionReadiness.isComplete(
            settings: appData.settings,
            password: appData.getPassword()
        )
    }

    var canAutoFill: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty && isPortValid
    }

    var canSave: Bool {
        !serverIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !shareName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty && isPortValid
    }

    private var isPortValid: Bool {
        guard !port.isEmpty else { return true }
        guard let value = Int(port) else { return false }
        return (1...65_535).contains(value)
    }

    var hasUnsavedChanges: Bool {
        serverIP != appData.settings.serverIP ||
        shareName != appData.settings.shareName ||
        targetDirectory != (appData.settings.targetDirectory ?? "") ||
        username != appData.settings.username ||
        port != (appData.settings.port.map(String.init) ?? "") ||
        password != (appData.getPassword() ?? "")
    }
    
    private var ocrModeBinding: Binding<OCRMode> {
        Binding(
            get: { OCRMode(rawValue: ocrModeRawValue) ?? .full },
            set: { ocrModeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        BackgroundContainerView {
            Form {
                if isFirstSetup {
                    firstSetupView
                } else {
                    completeSetupView
                }

                Section {
                    VStack(spacing: 4) {
                        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                           let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                            Text("Version \(appVersion) (\(buildNumber))")
                        }
                        Text("© Jan Hagen Clausen")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
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
        .alert(successTitle, isPresented: $showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(successMessage.isEmpty ? "Your settings have been saved successfully." : successMessage)
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
        .navigationBarBackButtonHidden(showWarning)
        .onChange(of: isFirstSetup) { _, _ in showAutoFillOption = false }
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
                        successTitle = "Review Server Settings"
                        successMessage = "Server details were found. Review them, then tap Save to keep this configuration."
                        showSuccess = true
                    }
                )
                .environmentObject(appData)
            }
        }
    }

    var firstSetupView: some View {
        Group {
            Section("Server Connection") {
                Text("Enter your credentials, then browse the local network or use a known server address. Your password is stored in Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Target Directory (optional)", text: $targetDirectory)
                    .autocapitalization(.none)
                TextField("Username (e.g., WORKGROUP\\user)", text: $username)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                TextField("Port (optional)", text: $port)
                    .keyboardType(.numberPad)
                if !isPortValid {
                    Label("Enter a port from 1 to 65535, or leave it empty.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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
                
                Button("Show All Settings") {
                    stopAutoFill()
                    isFirstSetup = false
                }
                .foregroundStyle(.blue)
                .accessibilityIdentifier("settings-manual-setup")
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
                    successTitle = "Review Server Settings"
                    successMessage = "Server details were found. Review them, then tap Save to keep this configuration."
                    showSuccess = true
                }
            }
        } message: {
            if let info = tempNetworkInfo {
                Text("Network information found:\nServer: \(info.serverIP)\nShare: \(info.shareName)\(info.targetDirectory.map { "\nDirectory: \($0)" } ?? "")\n\nDo you want to use this configuration?")
            }
        }
    }

    var completeSetupView: some View {
        Group {
            Section("Server Connection") {
                Text("Use Test Connection after entering the server details. It verifies that this iPhone can reach the SMB share and target directory; it does not test the journal system's import/watch folder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .accessibilityIdentifier("settings-server-ip")
                TextField("Share Name (e.g., MediaCaptureShare)", text: $shareName)
                    .autocapitalization(.none)
                    .accessibilityIdentifier("settings-share-name")
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
                if !isPortValid {
                    Label("Enter a port from 1 to 65535, or leave it empty.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                TextField("Username (e.g., WORKGROUP\\user)", text: $username)
                    .textContentType(.username)
                    .accessibilityIdentifier("settings-username")
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .accessibilityIdentifier("settings-password")

                Button("Test Connection") {
                    let operationID = UUID()
                    discoveryTask?.cancel()
                    activeDiscoveryOperationID = operationID
                    discoveryTask = Task { await testConnection(operationID: operationID) }
                }
                .disabled(!canSave || isDiscovering)
                .foregroundStyle(canSave && !isDiscovering ? .blue : .gray)
                .accessibilityIdentifier("settings-test-connection")
            }
            Section("Gallery") {
                Picker("Default Handling", selection: $appData.defaultGalleryOutputMode) {
                    ForEach(GalleryOutputMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("PDF Output") {
                Picker("Page Size", selection: $appData.pdfPageSize) {
                    Text("A4").tag(PDFPageSize.a4)
                    Text("Letter").tag(PDFPageSize.letter)
                }
                Picker("Image Layout", selection: $appData.pdfImageLayout) {
                    Text("Fit Whole Image").tag(PDFImageLayout.fit)
                    Text("Fill Page").tag(PDFImageLayout.fill)
                }
                Toggle("Include Page Numbers", isOn: $appData.pdfIncludePageNumbers)

                Picker("Compression", selection: $appData.pdfCompressionLevel) {
                    ForEach(PDFCompressionLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }

            Section("Image Handling") {
                Picker("Max Image Size", selection: $appData.imageMaxPixelDimension) {
                    Text("2048 px").tag(Double(2048))
                    Text("2500 px").tag(Double(2500))
                    Text("3000 px").tag(Double(3000))
                    Text("Original").tag(Double.greatestFiniteMagnitude)
                }
                Toggle("Strip Image Metadata Before Upload", isOn: $appData.stripImageMetadata)
            }

            ocrSection
            premiumSection
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
    
    var ocrSection: some View {
        Section("OCR") {
            Picker("OCR Mode", selection: ocrModeBinding) {
                ForEach(OCRMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    var premiumSection: some View {
        Section("Premium") {
            if appData.premiumAccess.state.canUsePremiumOverride {
                Toggle("Full App Unlock", isOn: Binding(
                    get: { appData.premiumAccess.state.isPremiumOverrideEnabled },
                    set: { appData.premiumAccess.setPremiumOverrideEnabled($0) }
                ))
                Text("Unlocks all uploads for TestFlight validation only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appData.premiumAccess.state.isFullAppUnlocked {
                Label("Full App Unlock active", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Text("\(appData.premiumAccess.state.remainingTrialUploads) trial uploads remaining")
                    .foregroundStyle(appData.premiumAccess.state.canUpload ? Color.secondary : Color.red)

                NavigationLink("Full App Unlock") {
                    FullAppUnlockView().environmentObject(appData)
                }
            }
        }
    }

    private func stopAutoFill() {
        discoveryTask?.cancel()
        discoveryTask = nil
        activeDiscoveryOperationID = nil
        isDiscovering = false
        searchProgress = "Ready"
    }

    private func startAutoFill() {
        let operationID = UUID()
        discoveryTask?.cancel()
        activeDiscoveryOperationID = operationID
        discoveryTask = Task {
            await performAutoFill(operationID: operationID)
        }
    }

    private func performAutoFill(operationID: UUID) async {
        guard activeDiscoveryOperationID == operationID else { return }
        isDiscovering = true
        searchProgress = "Checking network connection..."
        
        defer {
            Task { @MainActor in
                guard activeDiscoveryOperationID == operationID else { return }
                isDiscovering = false
                discoveryTask = nil
                activeDiscoveryOperationID = nil
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
                        guard activeDiscoveryOperationID == operationID else { return }
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
                guard activeDiscoveryOperationID == operationID else { return }
                tempNetworkInfo = info
                showAutoFillConfirmation = true
            }
        } catch is CancellationError {
            // Cancelled
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    guard activeDiscoveryOperationID == operationID else { return }
                    showError = true
                    errorMessage = "Failed to retrieve network info: \(error.localizedDescription)"
                }
            }
        }
    }

    private func testConnection(operationID: UUID) async {
        guard activeDiscoveryOperationID == operationID else { return }
        guard canSave else {
            showError = true
            errorMessage = "Enter the server IP, share name, username, and password before testing the connection."
            return
        }

        guard let target = SMBConnectionTarget(shareName: shareName, targetDirectory: targetDirectory) else {
            showError = true
            errorMessage = "Enter a valid SMB share name before testing the connection."
            return
        }

        isDiscovering = true
        searchProgress = "Testing SMB connection..."
        defer {
            Task { @MainActor in
                guard activeDiscoveryOperationID == operationID else { return }
                isDiscovering = false
                searchProgress = "Ready"
                discoveryTask = nil
                activeDiscoveryOperationID = nil
            }
        }

        do {
            let trimmedIP = serverIP.trimmingCharacters(in: .whitespacesAndNewlines)
            let info = try await appData.discoveryService.validateConnection(
                serverIP: trimmedIP,
                shareName: target.shareName,
                targetDirectory: target.targetDirectory,
                username: username,
                password: password,
                port: Int(port),
                onStatus: { status in
                    Task { @MainActor in
                        guard activeDiscoveryOperationID == operationID else { return }
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

            await MainActor.run {
                guard activeDiscoveryOperationID == operationID else { return }
                serverIP = info.serverIP
                shareName = info.shareName
                targetDirectory = info.targetDirectory ?? ""
                successTitle = "Connection Successful"
                successMessage = "Connection succeeded. The SMB share and target directory are reachable. The journal system still needs to import the uploaded file separately."
                showSuccess = true
            }
        } catch is CancellationError {
            // Cancelled by the user.
        } catch {
            if !Task.isCancelled {
                await MainActor.run {
                    guard activeDiscoveryOperationID == operationID else { return }
                    showError = true
                    errorMessage = "Connection test failed: \(error.localizedDescription)"
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
        isFirstSetup = !isSetupComplete
    }

    // MARK: - Improved Validation and Error Mapping
    func saveSettings() async {
        guard canSave else {
            showError = true
            errorMessage = "All required fields must be filled to save."
            return
        }

        // Port validity is enforced by canSave.
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
                successTitle = "Settings Saved"
                showSuccess = true
                successMessage = "Your settings have been saved successfully."
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
        .environmentObject(AppData.preview)
}
