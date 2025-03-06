//
//  SettingsView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appData: AppData
    @State private var serverIP = ""
    @State private var shareName = ""
    @State private var targetDirectory = "" // Still a String, but will allow empty
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var showHelpGuide = false

    var body: some View {
        Form {
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
                        Text("Optional - Target Directory (empty or e.g., Data/MediaCapture)")
                            .foregroundStyle(.gray)
                    }
                TextField("Username (e.g., WORKGROUP\\user)", text: $username)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            Section {
                Button("Save") { saveSettings() }
                Button("Reset", role: .destructive) { resetSettings() }
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
        .sheet(isPresented: $showHelpGuide) {
            HelpGuideView()
        }
        .safeAreaInset(edge: .bottom) {
            Text("(c) Jan H. Clausen, Midtbylægerne")
                .font(.caption2)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
        }
    }

    func loadSettings() {
        serverIP = appData.settings.serverIP
        shareName = appData.settings.shareName
        targetDirectory = appData.settings.targetDirectory ?? "" // Default to empty string if nil
        username = appData.settings.username
        password = appData.getPassword() ?? ""
    }

    func saveSettings() {
        guard !serverIP.isEmpty, !shareName.isEmpty else {
            showError = true
            errorMessage = "Server IP and Share Name are required."
            return
        }
        
        let ipComponents = serverIP.split(separator: ".")
        guard ipComponents.count == 4, ipComponents.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
            showError = true
            errorMessage = "Please enter a valid IP address (e.g., 192.168.1.10)"
            return
        }

        // Allow targetDirectory to be empty or nil
        let trimmedTargetDirectory = targetDirectory.trimmingCharacters(in: .init(charactersIn: "/\\"))
        let targetDir: String? = trimmedTargetDirectory.isEmpty ? nil : trimmedTargetDirectory

        appData.settings = ServerSettings(
            serverIP: serverIP,
            shareName: shareName,
            targetDirectory: targetDir, // Optional, can be nil
            username: username
        )
        do {
            try appData.savePassword(password)
            showSuccess = true
        } catch {
            showError = true
            errorMessage = "Failed to save password: \(error.localizedDescription)"
        }
    }

    func resetSettings() {
        serverIP = ""
        shareName = ""
        targetDirectory = ""
        username = ""
        password = ""
        appData.settings = ServerSettings(serverIP: "", shareName: "", targetDirectory: nil, username: "")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "serverPassword"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// Helper extension for placeholder (if not already defined elsewhere in your project)
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        self.overlay(shouldShow ? placeholder().alignmentGuide(.leading) { d in d[.leading] } : nil)
    }
}

//import SwiftUI
//
//struct SettingsView: View {
//    @EnvironmentObject var appData: AppData
//    @State private var serverIP = ""
//    @State private var shareName = ""
//    @State private var targetDirectory = ""
//    @State private var username = ""
//    @State private var password = ""
//    @State private var showError = false
//    @State private var errorMessage = ""
//    @State private var showSuccess = false
//    @State private var showHelpGuide = false
//
//    var body: some View {
//        Form {
//            Section("Server Configuration") {
//                TextField("Server IP (e.g., 192.168.1.100)", text: $serverIP)
//                    .textContentType(.URL)
//                    .keyboardType(.numbersAndPunctuation)
//                    .autocapitalization(.none)
//                TextField("Share Name (e.g., PatientImages)", text: $shareName)
//                    .autocapitalization(.none)
//                TextField("Target Directory (e.g., Uploads)", text: $targetDirectory)
//                    .autocapitalization(.none)
//                TextField("Username", text: $username)
//                    .textContentType(.username)
//                SecureField("Password", text: $password)
//                    .textContentType(.password)
//            }
//            Section {
//                Button("Save") { saveSettings() }
//                Button("Reset", role: .destructive) { resetSettings() }
//            }
//        }
//        .navigationTitle("Settings")
//        .toolbar {
//            ToolbarItem(placement: .automatic) {
//                Button("Help") { showHelpGuide = true }
//            }
//        }
//        .onAppear(perform: loadSettings)
//        .alert("Settings Error", isPresented: $showError) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text(errorMessage)
//        }
//        .alert("Settings Saved", isPresented: $showSuccess) {
//            Button("OK", role: .cancel) {}
//        } message: {
//            Text("Your settings have been saved successfully.")
//        }
//        .sheet(isPresented: $showHelpGuide) {
//            HelpGuideView()
//        }
//        .safeAreaInset(edge: .bottom) {
//            Text("(c) Jan H. Clausen, Midtbylægerne")
//                .font(.caption2)
//                .foregroundStyle(.gray)
//                .frame(maxWidth: .infinity)
//                .padding(.vertical, 5)
//        }
//    }
//
//    func loadSettings() {
//        serverIP = appData.settings.serverIP
//        shareName = appData.settings.shareName
//        targetDirectory = appData.settings.targetDirectory
//        username = appData.settings.username
//        password = appData.getPassword() ?? ""
//    }
//
//    func saveSettings() {
//        guard !serverIP.isEmpty, !shareName.isEmpty else {
//            showError = true
//            errorMessage = "Server IP and Share Name are required."
//            return
//        }
//        
//        let ipComponents = serverIP.split(separator: ".")
//        guard ipComponents.count == 4, ipComponents.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
//            showError = true
//            errorMessage = "Please enter a valid IP address (e.g., 192.168.1.100)"
//            return
//        }
//
//        appData.settings = ServerSettings(
//            serverIP: serverIP,
//            shareName: shareName,
//            targetDirectory: targetDirectory.trimmingCharacters(in: .init(charactersIn: "/\\")),
//            username: username
//        )
//        do {
//            try appData.savePassword(password)
//            showSuccess = true
//        } catch {
//            showError = true
//            errorMessage = "Failed to save password: \(error.localizedDescription)"
//        }
//    }
//
//    func resetSettings() {
//        serverIP = ""
//        shareName = ""
//        targetDirectory = ""
//        username = ""
//        password = ""
//        appData.settings = ServerSettings(serverIP: "", shareName: "", targetDirectory: "", username: "")
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrAccount as String: "serverPassword"
//        ]
//        SecItemDelete(query as CFDictionary)
//    }
//}
