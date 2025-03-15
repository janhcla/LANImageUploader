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
    @State private var isFirstSetup = false
    @State private var showAutoFillOption = false
    @State private var port: String = ""

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

    var body: some View {
        Form {
            if isFirstSetup || !isSetupComplete {
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
        .sheet(isPresented: $showHelpGuide) {
            HelpGuideView()
        }
        .safeAreaInset(edge: .bottom) {
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
        .navigationBarBackButtonHidden(showWarning)
        .onChange(of: isFirstSetup) { _, _ in showAutoFillOption = false }
    }

    var firstSetupView: some View {
            Group {
                Section("First Setup") {
                    Text("Enter credentials and target folder to auto-fill server details.")
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
                    Task { await autoFillNetworkInfo() }
                }
                .disabled(!canAutoFill)
                .foregroundStyle(canAutoFill ? .blue : .gray)
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
                Button("Save") { saveSettings() }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? .green : .gray)
                Button("Discard", role: .destructive) { discardChanges() }
                Button("Reset", role: .destructive) { resetSettings() }
                if showAutoFillOption {
                    Button("Auto-Fill Network Info") { isFirstSetup = true }
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

        func saveSettings() {
            guard canSave else {
                showError = true
                errorMessage = "All fields must be filled to save."
                return
            }
            
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

    private func autoFillNetworkInfo() async {
        do {
            let portNumber = Int(port)
            let info = try await retrieveNetworkInfo(
                targetFolder: targetDirectory,
                username: username,
                password: password,
                directIP: nil,
                port: portNumber
            )
            await MainActor.run {
                serverIP = info.serverIP
                shareName = info.shareName
                targetDirectory = info.targetDirectory ?? ""
                isFirstSetup = false
            }
        } catch {
            await MainActor.run {
                showError = true
                errorMessage = "Failed to retrieve network info: \(error.localizedDescription)"
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
        showAutoFillOption = true
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

