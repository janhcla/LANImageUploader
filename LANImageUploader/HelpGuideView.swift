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
                    Text("Share Name: Enter the name of the shared folder on your server, e.g., 'Images'. Set this up in Windows File Explorer under 'Share' settings.")
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
