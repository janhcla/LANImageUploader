//
//  HelpGuideView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 22/02/2025.
//

import SwiftUI

struct HelpGuideView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("onboardingCompleted") var onboardingCompleted: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Server Setup") {
                    Text("Server IP: Enter your Windows server’s IP address, e.g., '192.168.1.100'. Find it using 'ipconfig' in Command Prompt on the server.")
                    Text("Share Name: Enter the name of the shared folder on your server, e.g., 'PatientImages'. Set this up in Windows File Explorer under 'Share' settings.")
                    Text("Target Directory: Optional - Specify a subfolder within the share for uploads, e.g., 'Uploads'. Ensure it exists or will be created by the server.")
                    Text("Username and Password: Use your Windows credentials or a specific user account with access to the share. Contact your IT department if unsure.")
                }
                Section("Troubleshooting") {
                    Text("Connection Issues: Ensure you’re on the same network as the server, the IP is correct, and the share is accessible. Test by connecting via Files app on iOS.")
                    Text("Upload Failed: Verify all settings (IP, share name, directory, credentials) are complete in Settings. Missing details prevent uploads.")
                }
                Section("Onboarding") {
                    Button("Revisit Onboarding") {
                        onboardingCompleted = false
                        dismiss()
                    }
                }
            }
            .navigationTitle("Help Guide")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

//import SwiftUI
//
//struct HelpGuideView: View {
//    @Environment(\.dismiss) var dismiss
//    @AppStorage("onboardingCompleted") var onboardingCompleted: Bool = false
//
//    var body: some View {
//        NavigationStack {
//            List {
//                Section("Server Setup") {
//                    Text("Server URL: Enter your local server IP, e.g., '192.168.1.100'. The app will prepend 'http://' if needed.")
//                    Text("How to Find Server IP: Check your router settings (see [Apple Support: Find Your Router’s IP](https://support.apple.com/en-us/HT202213)) or use network tools like 'ipconfig' (Windows) or 'ifconfig' (macOS). Contact IT if unsure.")
//                    Text("Destination Directory: Set the folder on the server for uploads, e.g., '/uploads'. Ask your server administrator for the correct path.")
//                    Text("Username and Password: Use secure credentials for server access. Obtain these from your IT department and keep them confidential.")
//                }
//                Section("Troubleshooting") {
//                    Text("Connection Timeout: Ensure the server is online and you’re connected to the same network. Verify the IP and credentials.")
//                    Text("Upload Failed: Check that server settings are complete in Settings. Missing details prevent uploads.")
//                }
//                Section("Onboarding") {
//                    Button("Revisit Onboarding") {
//                        onboardingCompleted = false
//                        dismiss()
//                    }
//                }
//            }
//            .navigationTitle("Help Guide")
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Close") {
//                        dismiss()
//                    }
//                }
//            }
//        }
//    }
//}
