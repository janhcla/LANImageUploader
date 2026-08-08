//
//  OnboardingView.swift
//  LANImageUploader
//

import SwiftUI

public struct OnboardingView: View {
    @AppStorage(Constants.UserDefaults.onboardingCompleted) private var onboardingCompleted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0

    private let pages = OnboardingPage.allCases

    public var body: some View {
        BackgroundContainerView {
            VStack(spacing: 0) {
                OnboardingHeader(
                    currentPage: selectedPage,
                    pageCount: pages.count,
                    reduceMotion: reduceMotion,
                    isLastPage: selectedPage == pages.count - 1,
                    onSkip: completeOnboarding
                )

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.element) { (index, page) in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .snappy, value: selectedPage)

                OnboardingFooter(
                    isFirstPage: selectedPage == 0,
                    isLastPage: selectedPage == pages.count - 1,
                    onBack: previousPage,
                    onContinue: advance
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private func previousPage() {
        guard selectedPage > 0 else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            selectedPage -= 1
        }
    }

    private func advance() {
        guard selectedPage < pages.count - 1 else {
            completeOnboarding()
            return
        }
        withAnimation(reduceMotion ? nil : .snappy) {
            selectedPage += 1
        }
    }

    private func completeOnboarding() {
        onboardingCompleted = true
    }
}

enum OnboardingPage: String, CaseIterable {
    case privacy
    case capture
    case organize
    case ready

    var title: String {
        switch self {
        case .privacy: "Capture anything. Keep it private."
        case .capture: "Photo or document"
        case .organize: "Your gallery, your workflow"
        case .ready: "You're ready"
        }
    }

    var message: String {
        switch self {
        case .privacy:
            "Photos and documents stay on your device until you choose to upload them to a local server. This app does not provide cloud backup or a patient journal."
        case .capture:
            "Take a photo, or scan multi-page documents with edge detection, auto-capture, crop, and rotation."
        case .organize:
            "Rename, reorder, archive, or combine selected images into one optimized PDF."
        case .ready:
            "Start capturing now. To upload, connect your SMB server from Settings. Your journal system must already support importing files from a watched folder."
        }
    }

    var systemImage: String {
        switch self {
        case .privacy: "lock.shield.fill"
        case .capture: "doc.viewfinder"
        case .organize: "photo.stack.fill"
        case .ready: "checkmark"
        }
    }

    var tint: Color {
        switch self {
        case .privacy: .blue
        case .capture: .indigo
        case .organize: .teal
        case .ready: .green
        }
    }

    var detailItems: [OnboardingDetailItem] {
        switch self {
        case .privacy:
            [
                OnboardingDetailItem(icon: "iphone", title: "On-device by default", detail: "Your gallery and archives remain local."),
                OnboardingDetailItem(icon: "network", title: "Your network, your server", detail: "Uploads go only to the SMB share you configure."),
                OnboardingDetailItem(icon: "exclamationmark.triangle.fill", title: "Not a journal system", detail: "Your existing journal system must import files from its own watched folder.")
            ]
        case .capture:
            [
                OnboardingDetailItem(icon: "camera.fill", title: "Capture photos", detail: "Take, review, and retake high-quality images."),
                OnboardingDetailItem(icon: "rectangle.stack.fill", title: "Scan documents", detail: "Capture several pages in portrait or landscape.")
            ]
        case .organize:
            [
                OnboardingDetailItem(icon: "doc.richtext.fill", title: "Create PDFs", detail: "Choose page size, layout, page numbers, and compression."),
                OnboardingDetailItem(icon: "archivebox.fill", title: "Keep work organized", detail: "Rename items and restore them from dated archives.")
            ]
        case .ready:
            [
                OnboardingDetailItem(icon: "gearshape.fill", title: "Settings > Server Connection", detail: "Add your server, share, username, and password."),
                OnboardingDetailItem(icon: "checkmark.shield.fill", title: "Verify the journal workflow", detail: "Confirm the server folder and filename rules with your journal vendor."),
                OnboardingDetailItem(icon: "house.fill", title: "Follow the Home setup card", detail: "It remains visible until upload is ready.")
            ]
        }
    }
}

struct OnboardingDetailItem: Identifiable {
    let icon: String
    let title: String
    let detail: String

    var id: String { title }
}

private struct OnboardingHeader: View {
    let currentPage: Int
    let pageCount: Int
    let reduceMotion: Bool
    let isLastPage: Bool
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            OnboardingProgress(
                currentPage: currentPage,
                pageCount: pageCount,
                reduceMotion: reduceMotion
            )
            Spacer()
            if !isLastPage {
                Button("Skip", action: onSkip)
                    .buttonStyle(.glass)
                    .accessibilityHint("Closes onboarding and opens the app")
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 48)
    }
}

private struct OnboardingProgress: View {
    let currentPage: Int
    let pageCount: Int
    let reduceMotion: Bool

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<pageCount, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.28))
                    .frame(width: index == currentPage ? 28 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: currentPage)
        .accessibilityElement()
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("Page \(currentPage + 1) of \(pageCount)")
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 6)

                AppSymbolTile(systemImage: page.systemImage, tint: page.tint, size: 84)

                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text(page.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: 560)

                GlassEffectContainer(spacing: 14) {
                    VStack(spacing: 14) {
                        ForEach(page.detailItems) { item in
                            OnboardingDetailRow(item: item, tint: page.tint)
                        }
                    }
                }
                .frame(maxWidth: 560)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding-\(page.rawValue)")
    }
}

private struct OnboardingDetailRow: View {
    let item: OnboardingDetailItem
    let tint: Color

    var body: some View {
        AppGlassCard(tint: tint) {
            HStack(spacing: 14) {
                Image(systemName: item.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct OnboardingFooter: View {
    let isFirstPage: Bool
    let isLastPage: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if !isFirstPage {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Previous page")
            }

            Button(action: onContinue) {
                FullWidthGlassButtonLabel(
                    isLastPage ? "Start using the app" : "Continue",
                    systemImage: isLastPage ? "checkmark" : "arrow.right"
                )
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier(isLastPage ? "finish-onboarding" : "continue-onboarding")
        }
        .padding(.top, 8)
    }
}

#Preview {
    OnboardingView()
}
