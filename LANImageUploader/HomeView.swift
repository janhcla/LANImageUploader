//
//  HomeView.swift
//  LANImageUploader
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appData: AppData
    @State private var activeCameraMode: CameraCaptureMode?

    private var isServerConnectionComplete: Bool {
        ServerConnectionReadiness.isComplete(
            settings: appData.settings,
            password: appData.getPassword()
        )
    }

    var body: some View {
        NavigationStack {
            BackgroundContainerView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HomeHeader()

                        if !isServerConnectionComplete {
                            ServerSetupCard()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        HomeCaptureActions(activeCameraMode: $activeCameraMode)
                        HomeLibraryActions()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("ImageDropX")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(item: $activeCameraMode) { mode in
                CameraView(initialMode: mode)
                    .environmentObject(appData)
            }
            .animation(.snappy, value: isServerConnectionComplete)
        }
    }
}

enum ServerConnectionReadiness {
    static func isComplete(settings: ServerSettings, password: String?) -> Bool {
        !settings.serverIP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settings.shareName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !settings.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !(password?.isEmpty ?? true)
    }
}

private struct HomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Capture. Organize. Upload.")
                .font(.largeTitle.bold())
            Text("Photos and documents stay on this device until you send them to your local server.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ServerSetupCard: View {
    var body: some View {
        AppGlassCard(tint: .blue) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AppSymbolTile(systemImage: "network", tint: .blue, size: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get upload ready")
                            .font(.title3.bold())
                        Text("Connect your local SMB server. Capture and scanning already work without it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                NavigationLink {
                    SettingsView()
                } label: {
                    FullWidthGlassButtonLabel("Open Server Connection", systemImage: "arrow.right")
                }
                .buttonStyle(.glassProminent)

                Label("Settings > Server Connection", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .accessibilityIdentifier("server-setup-card")
    }
}

private struct HomeCaptureActions: View {
    @Binding var activeCameraMode: CameraCaptureMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    HomeActionButton(
                        title: "Capture Image",
                        subtitle: "Take a photo",
                        systemImage: "camera.fill",
                        tint: .blue
                    ) {
                        activeCameraMode = .photo
                    }

                    HomeActionButton(
                        title: "Scan Documents",
                        subtitle: "Multi-page scan",
                        systemImage: "doc.viewfinder",
                        tint: .indigo
                    ) {
                        activeCameraMode = .scan
                    }
                }
            }
        }
    }
}

private struct HomeLibraryActions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library & Transfer")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    NavigationLink {
                        GalleryView()
                    } label: {
                        HomeActionCard(
                            title: "Gallery",
                            subtitle: "Organize & create PDF",
                            systemImage: "photo.stack.fill",
                            tint: .green
                        )
                    }

                    NavigationLink {
                        UploadView()
                    } label: {
                        HomeActionCard(
                            title: "Upload",
                            subtitle: "Send queued files",
                            systemImage: "arrow.up.circle.fill",
                            tint: .orange
                        )
                    }

                    NavigationLink {
                        ArchiveView()
                    } label: {
                        HomeActionCard(
                            title: "Archives",
                            subtitle: "Restore saved work",
                            systemImage: "archivebox.fill",
                            tint: .purple
                        )
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        HomeActionCard(
                            title: "Settings",
                            subtitle: "Server, PDF & privacy",
                            systemImage: "gearshape.fill",
                            tint: .gray
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HomeActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HomeActionCard(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint
            )
        }
        .buttonStyle(.plain)
    }
}

private struct HomeActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.tint(tint.opacity(0.1)).interactive(), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }
}

#Preview {
    HomeView()
        .environmentObject(AppData.preview)
}
