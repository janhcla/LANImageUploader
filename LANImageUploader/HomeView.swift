//
//  HomeView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appData: AppData

    var areSettingsComplete: Bool {
        !appData.settings.serverIP.isEmpty &&
        !appData.settings.shareName.isEmpty &&
        !(appData.settings.targetDirectory?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) &&
        !appData.settings.username.isEmpty &&
        appData.getPassword() != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink(destination: CameraView()) {
                    Label("Capture Image", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                NavigationLink(destination: GalleryView()) {
                    Label("View Gallery", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                NavigationLink(destination: UploadView()) {
                    Label("Upload", systemImage: "arrow.up.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .badge(areSettingsComplete ? nil : Text("!"))
                .badgeProminence(.increased)
                NavigationLink(destination: ArchiveView()) {
                    Label("Archives", systemImage: "archivebox")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .background(Color.clear) // Add to VStack
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .navigationTitle("DermaSnap")
            .animation(.easeInOut, value: true)
        }
        .background(Color.clear) // Ensures NavigationStack doesn't override the gradient
    }
}
