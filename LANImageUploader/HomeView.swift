//
//  HomeView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI

struct TransparentNavigationBar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .navigationBarTitleDisplayMode(.large)
    }
}

extension View {
    func withTransparentNavigationBar() -> some View {
        self.modifier(TransparentNavigationBar())
    }
}

struct HomeView: View {
    @EnvironmentObject var appData: AppData
    @State private var hasAppeared = false
    @Environment(\.colorScheme) private var colorScheme
    
    var areSettingsComplete: Bool {
        !appData.settings.serverIP.isEmpty && !appData.settings.shareName.isEmpty
            && !appData.settings.username.isEmpty && appData.getPassword() != nil
    }

    var body: some View {
        NavigationStack {
            Color.clear
                .ignoresSafeArea()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            colorScheme == .dark ? Color(uiColor: .systemGray2) : Color.white,
                            colorScheme == .dark ? Color.black : Color(uiColor: .systemGray3)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .overlay(
                    VStack {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            NavigationLink(destination: CameraView()) {
                                Label("Capture Image", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            NavigationLink(destination: GalleryView()) {
                                Label("View Gallery", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            NavigationLink(destination: UploadView()) {
                                Label("Upload", systemImage: "arrow.up.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            NavigationLink(destination: SettingsView()) {
                                Label("Settings", systemImage: "gear")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .badge(areSettingsComplete ? nil : "!")
                            .badgeProminence(.increased)
                            
                            NavigationLink(destination: ArchiveView()) {
                                Label("Archives", systemImage: "archivebox")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                )
                .navigationTitle("ImageDropX")
                .toolbarColorScheme(colorScheme, for: .navigationBar)
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            if !hasAppeared {
                DispatchQueue.main.async {
                    if #available(iOS 15.0, *) {
                        let appearance = UINavigationBarAppearance()
                        appearance.configureWithTransparentBackground()
                        appearance.backgroundColor = UIColor.clear
                        appearance.shadowColor = nil
                        
                        let textColor = colorScheme == .dark ? UIColor.white : UIColor.black
                        appearance.titleTextAttributes = [.foregroundColor: textColor]
                        appearance.largeTitleTextAttributes = [.foregroundColor: textColor]
                        
                        UINavigationBar.appearance().standardAppearance = appearance
                        UINavigationBar.appearance().compactAppearance = appearance
                        UINavigationBar.appearance().scrollEdgeAppearance = appearance
                    } else {
                        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
                        UINavigationBar.appearance().shadowImage = UIImage()
                        UINavigationBar.appearance().isTranslucent = true
                        UINavigationBar.appearance().backgroundColor = .clear
                    }
                    hasAppeared = true
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppData.preview)
}
