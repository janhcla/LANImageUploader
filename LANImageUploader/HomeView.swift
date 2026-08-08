//
//  HomeView.swift
//  LANImageUploader
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appData: AppData
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    VStack(alignment: .leading, spacing: 18) {
                        HomeHeader()

                        HomeCaptureActions(activeCameraMode: $activeCameraMode)

                        if !isServerConnectionComplete {
                            ServerSetupCard()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        HomeLibraryActions()
                    }
                    .padding(20)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .fullScreenCover(item: $activeCameraMode) { mode in
                CameraView(initialMode: mode)
                    .environmentObject(appData)
            }
            .animation(reduceMotion ? nil : .snappy, value: isServerConnectionComplete)
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
        .dynamicTypeSize(.xSmall ... .accessibility1)
        .accessibilityElement(children: .combine)
    }
}

private struct ServerSetupCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationLink {
            SettingsView()
        } label: {
            AppGlassCard(tint: .blue) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        AppSymbolTile(systemImage: "network", tint: .blue, size: 48)
                        serverSetupText
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(spacing: 14) {
                        AppSymbolTile(systemImage: "network", tint: .blue, size: 48)
                        serverSetupText
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("server-setup-card")
    }

    private var serverSetupText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Connect your server")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Required only when you're ready to upload")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HomeCaptureActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var activeCameraMode: CameraCaptureMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 12) { actionCards }
                    } else {
                        HStack(spacing: 12) { actionCards }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionCards: some View {
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

private struct HomeLibraryActions: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Library & Transfer")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                LazyVGrid(
                    columns: dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    NavigationLink {
                        GalleryView()
                    } label: {
                        HomeActionCard(
                            title: "Gallery",
                            subtitle: "Organize & create PDF",
                            systemImage: "photo.stack.fill",
                            tint: .green,
                            glassTintOpacity: 0.035
                        )
                    }
                    .accessibilityIdentifier("home-gallery")

                    NavigationLink {
                        UploadView()
                    } label: {
                        HomeActionCard(
                            title: "Upload",
                            subtitle: "Send queued files",
                            systemImage: "arrow.up.circle.fill",
                            tint: .orange,
                            glassTintOpacity: 0.035
                        )
                    }
                    .accessibilityIdentifier("home-upload")

                    NavigationLink {
                        ArchiveView()
                    } label: {
                        HomeActionCard(
                            title: "Archives",
                            subtitle: "Restore saved work",
                            systemImage: "archivebox.fill",
                            tint: .purple,
                            glassTintOpacity: 0.035
                        )
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        HomeActionCard(
                            title: "Settings",
                            subtitle: "Server, PDF & privacy",
                            systemImage: "gearshape.fill",
                            tint: .gray,
                            glassTintOpacity: 0.035
                        )
                    }
                    .accessibilityIdentifier("home-settings")
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
        .accessibilityIdentifier(title == "Scan Documents" ? "home-scan-documents" : "home-capture-image")
    }
}

private struct HomeActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var glassTintOpacity = 0.08
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.tint(tint.opacity(glassTintOpacity)).interactive(), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }
}

#Preview {
    HomeView()
        .environmentObject(AppData.preview)
}
