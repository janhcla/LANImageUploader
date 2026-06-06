//
//  HelpGuideView.swift
//  LANImageUploader
//

import SwiftUI

struct HelpGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Constants.UserDefaults.onboardingCompleted) private var onboardingCompleted = false
    @State private var searchText = ""

    private var searchResults: [HelpArticle] {
        HelpContent.search(searchText)
    }

    var body: some View {
        NavigationStack {
            BackgroundContainerView {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        HelpQuickActions(onReplayOnboarding: replayOnboarding)

                        if searchText.isEmpty {
                            HelpTopicGrid()
                            FeaturedHelpSection()
                        } else {
                            HelpSearchResults(articles: searchResults, query: searchText)
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Help Center")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search help")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
            .navigationDestination(for: HelpTopic.self) { topic in
                HelpTopicView(topic: topic)
            }
            .navigationDestination(for: HelpArticle.self) { article in
                HelpArticleView(article: article)
            }
        }
    }

    private func replayOnboarding() {
        onboardingCompleted = false
        dismiss()
    }
}

enum HelpTopic: String, CaseIterable, Identifiable, Hashable {
    case capture
    case gallery
    case upload
    case archive
    case privacy
    case troubleshooting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .capture: "Photos & Scanner"
        case .gallery: "Gallery & PDF"
        case .upload: "Upload & Server"
        case .archive: "Archive & Files"
        case .privacy: "Privacy & Storage"
        case .troubleshooting: "Troubleshooting"
        }
    }

    var summary: String {
        switch self {
        case .capture: "Capture photos and scan multi-page documents."
        case .gallery: "Organize images and create PDFs."
        case .upload: "Connect and upload to your SMB share."
        case .archive: "Save, restore, rename, and delete archives."
        case .privacy: "Understand local storage and image handling."
        case .troubleshooting: "Resolve permissions, connection, and upload issues."
        }
    }

    var systemImage: String {
        switch self {
        case .capture: "doc.viewfinder"
        case .gallery: "doc.richtext.fill"
        case .upload: "network"
        case .archive: "archivebox.fill"
        case .privacy: "hand.raised.fill"
        case .troubleshooting: "wrench.and.screwdriver.fill"
        }
    }

    var tint: Color {
        switch self {
        case .capture: .blue
        case .gallery: .indigo
        case .upload: .teal
        case .archive: .orange
        case .privacy: .purple
        case .troubleshooting: .gray
        }
    }

    var articles: [HelpArticle] {
        HelpContent.articles.filter { $0.topic == self }
    }
}

struct HelpArticle: Identifiable, Hashable {
    let id: String
    let topic: HelpTopic
    let title: String
    let summary: String
    let keywords: [String]
    let steps: [String]
    let tip: String?
    let warning: String?

    var searchableText: String {
        ([title, summary] + keywords + steps)
            .joined(separator: " ")
            .localizedLowercase
    }
}

enum HelpContent {
    static let articles: [HelpArticle] = [
        HelpArticle(
            id: "capture-photo",
            topic: .capture,
            title: "Capture a photo",
            summary: "Take a photo, review it, and save it to the local Gallery.",
            keywords: ["camera", "picture", "retake", "zoom"],
            steps: [
                "Tap Capture Image on Home.",
                "Frame the subject and use the zoom controls if needed.",
                "Tap the shutter button, then review the result.",
                "Retake the photo or save it to Gallery."
            ],
            tip: "Landscape capture is supported. The saved image follows the device orientation.",
            warning: nil
        ),
        HelpArticle(
            id: "scan-document",
            topic: .capture,
            title: "Scan a multi-page document",
            summary: "Use edge detection and auto-capture to collect document pages.",
            keywords: ["scan", "document", "page", "auto capture", "edge detection"],
            steps: [
                "Tap Scan Documents on Home.",
                "Hold the device over a page until its edges are detected.",
                "Let auto-capture take the page, or use the shutter button manually.",
                "Continue scanning until every page has been captured.",
                "Review the pages and finish to save them in Gallery."
            ],
            tip: "Turn off Auto-capture in the scanner when you need precise manual timing.",
            warning: nil
        ),
        HelpArticle(
            id: "review-scan",
            topic: .capture,
            title: "Review, crop, and rotate scans",
            summary: "Correct page boundaries and orientation before creating a PDF.",
            keywords: ["crop", "rotate", "review", "retake", "orientation"],
            steps: [
                "Open the captured page in the scanner review flow.",
                "Adjust the crop corners to match the document edges.",
                "Rotate the page until text is upright.",
                "Retake a page if focus or lighting is poor.",
                "Confirm the page to keep the corrected result."
            ],
            tip: nil,
            warning: "Check every page before combining scans into a PDF."
        ),
        HelpArticle(
            id: "manage-gallery",
            topic: .gallery,
            title: "Organize Gallery items",
            summary: "Select, rename, reorder, delete, archive, or upload local items.",
            keywords: ["gallery", "rename", "select", "reorder", "delete", "batch"],
            steps: [
                "Open View Gallery from Home.",
                "Select one or more items for batch actions.",
                "Rename items individually or use the batch naming flow.",
                "Reorder selected pages before creating a combined PDF.",
                "Archive, upload, or delete items when ready."
            ],
            tip: "Use clear names before upload so files are easy to identify on the server.",
            warning: nil
        ),
        HelpArticle(
            id: "create-pdf",
            topic: .gallery,
            title: "Create and upload one PDF",
            summary: "Combine selected Gallery images or scans into a single PDF.",
            keywords: ["pdf", "combine", "single pdf", "pages", "compression"],
            steps: [
                "Select the images or scanned pages in Gallery.",
                "Choose Single PDF as the output mode.",
                "Arrange pages in the required order and enter a file name.",
                "Create the PDF and review the upload screen.",
                "Upload it now or keep the source pages in Gallery."
            ],
            tip: "PDF page size, image fit, page numbers, and compression are configured in Settings.",
            warning: nil
        ),
        HelpArticle(
            id: "pdf-settings",
            topic: .gallery,
            title: "Choose PDF output settings",
            summary: "Control page size, image fit, page numbers, and compression.",
            keywords: ["a4", "letter", "fit", "fill", "page number", "quality"],
            steps: [
                "Open Settings.",
                "Find the PDF Output section.",
                "Choose A4 or Letter page size.",
                "Choose Fit Whole Image or Fill Page.",
                "Set page numbers and compression for future PDFs."
            ],
            tip: "Fit Whole Image avoids cropping. Fill Page uses the full page but may crop edges.",
            warning: nil
        ),
        HelpArticle(
            id: "connect-server",
            topic: .upload,
            title: "Connect your SMB server",
            summary: "Configure the local server used for image and PDF uploads.",
            keywords: ["smb", "server", "share", "username", "password", "port", "settings"],
            steps: [
                "Open Settings and find Server Connection.",
                "Enter your target directory, username, password, and optional port.",
                "Browse the network for servers, try a direct IP, or switch to manual setup.",
                "Confirm the server IP and share name.",
                "Save the settings, then return to Home."
            ],
            tip: "The password is stored in the iOS Keychain. Other server settings are stored locally.",
            warning: "Your device and SMB server must be reachable on the same local network."
        ),
        HelpArticle(
            id: "upload-files",
            topic: .upload,
            title: "Upload images or PDFs",
            summary: "Send Gallery items to the configured local network share.",
            keywords: ["upload", "queue", "retry", "duplicate", "overwrite"],
            steps: [
                "Select files in Gallery, or open Upload to use the current queue.",
                "Review file names and confirm that Server Connection is complete.",
                "Start the upload and keep the app open while transfers are active.",
                "Retry failed files or follow the displayed guidance.",
                "For a duplicate name, rename the file or explicitly overwrite it."
            ],
            tip: "The free trial includes 15 successful uploads. Full App Unlock removes that limit.",
            warning: "Do not leave the network while an upload is active."
        ),
        HelpArticle(
            id: "manage-archives",
            topic: .archive,
            title: "Archive and restore Gallery items",
            summary: "Move local images into dated archives and restore them later.",
            keywords: ["archive", "restore", "date", "rename archive", "delete archive"],
            steps: [
                "Select Gallery items and choose Save to Archive.",
                "Open Archives from Home to view dated groups.",
                "Rename an archive when a descriptive label is more useful than its date.",
                "Select an archive to restore its files to Gallery.",
                "Delete archives only after confirming their contents are no longer needed."
            ],
            tip: "Archives remain in the app's Documents folder on this device.",
            warning: "Deleting an archive permanently removes its local files."
        ),
        HelpArticle(
            id: "privacy-storage",
            topic: .privacy,
            title: "How ImageDropX handles your data",
            summary: "Images, documents, settings, and credentials remain under your control.",
            keywords: ["privacy", "local", "storage", "metadata", "keychain", "cloud"],
            steps: [
                "Captured images are stored locally in the app's Documents folder.",
                "Archives are organized locally by date.",
                "Uploads go only to the SMB destination you configure.",
                "Passwords are stored in the iOS Keychain.",
                "Use Strip Image Metadata Before Upload in Settings when metadata should be removed."
            ],
            tip: "ImageDropX includes no analytics, telemetry, or cloud synchronization.",
            warning: nil
        ),
        HelpArticle(
            id: "connection-troubleshooting",
            topic: .troubleshooting,
            title: "Server cannot be found",
            summary: "Check network access, server details, and SMB permissions.",
            keywords: ["connection", "network", "bonjour", "direct ip", "not found", "permission"],
            steps: [
                "Confirm the iPhone or iPad is connected to the same network as the server.",
                "Allow Local Network access for ImageDropX in iOS Settings.",
                "Try the server IP directly if discovery finds no results.",
                "Verify the share name, username, password, and optional port.",
                "Confirm the account can access the share from another device."
            ],
            tip: "The iOS Files app can help confirm whether the SMB server is reachable.",
            warning: nil
        ),
        HelpArticle(
            id: "upload-troubleshooting",
            topic: .troubleshooting,
            title: "An upload failed",
            summary: "Use the failure message to correct settings, names, or access.",
            keywords: ["failed", "error", "unreadable", "authentication", "duplicate"],
            steps: [
                "Open the failed item to read its reason and guidance.",
                "Check Server Connection when authentication or destination details are incomplete.",
                "Rename the file when the server already contains the same name.",
                "Confirm the target directory exists and the account can write to it.",
                "Retry only the failed items after correcting the issue."
            ],
            tip: nil,
            warning: "Repeated authentication failures usually mean the username, password, or share permissions are incorrect."
        )
    ]

    static func search(_ query: String) -> [HelpArticle] {
        let terms = query
            .localizedLowercase
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard !terms.isEmpty else { return articles }
        return articles.filter { article in
            terms.allSatisfy { article.searchableText.contains($0) }
        }
    }
}

private struct HelpQuickActions: View {
    let onReplayOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Start")
                .font(.headline)

            AppGlassCard(tint: .blue) {
                if let connectServerArticle = HelpContent.articles.first(where: { $0.id == "connect-server" }) {
                    NavigationLink(value: connectServerArticle) {
                        HelpActionRow(
                            systemImage: "network",
                            tint: .blue,
                            title: "Connect your server",
                            subtitle: "Set up local SMB upload"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .padding(.vertical, 8)

                Button(action: onReplayOnboarding) {
                    HelpActionRow(
                        systemImage: "play.fill",
                        tint: .indigo,
                        title: "Replay onboarding",
                        subtitle: "Review the essentials"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HelpActionRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct HelpTopicGrid: View {
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browse Topics")
                .font(.headline)

            GlassEffectContainer(spacing: 12) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(HelpTopic.allCases) { topic in
                        NavigationLink(value: topic) {
                            HelpTopicCard(topic: topic)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct HelpTopicCard: View {
    let topic: HelpTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: topic.systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(topic.tint)
            Text(topic.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            Text(topic.articles.count == 1 ? "1 guide" : "\(topic.articles.count) guides")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }
}

private struct FeaturedHelpSection: View {
    private let articleIDs = ["scan-document", "create-pdf", "connection-troubleshooting"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Popular Guides")
                .font(.headline)

            AppGlassCard {
                ForEach(Array(featuredArticles.enumerated()), id: \.element.id) { index, article in
                    NavigationLink(value: article) {
                        HelpArticleRow(article: article)
                    }
                    .buttonStyle(.plain)

                    if index < featuredArticles.count - 1 {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
        }
    }

    private var featuredArticles: [HelpArticle] {
        articleIDs.compactMap { id in HelpContent.articles.first { $0.id == id } }
    }
}

private struct HelpSearchResults: View {
    let articles: [HelpArticle]
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Search Results")
                .font(.headline)

            if articles.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 50)
            } else {
                AppGlassCard {
                    ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                        NavigationLink(value: article) {
                            HelpArticleRow(article: article)
                        }
                        .buttonStyle(.plain)

                        if index < articles.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }
            }
        }
    }
}

private struct HelpArticleRow: View {
    let article: HelpArticle

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: article.topic.systemImage)
                .foregroundStyle(article.topic.tint)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(article.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct HelpTopicView: View {
    let topic: HelpTopic

    var body: some View {
        BackgroundContainerView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AppSymbolTile(systemImage: topic.systemImage, tint: topic.tint)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(topic.title)
                            .font(.largeTitle.bold())
                        Text(topic.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    AppGlassCard(tint: topic.tint) {
                        ForEach(Array(topic.articles.enumerated()), id: \.element.id) { index, article in
                            NavigationLink(value: article) {
                                HelpArticleRow(article: article)
                            }
                            .buttonStyle(.plain)

                            if index < topic.articles.count - 1 {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpArticleView: View {
    let article: HelpArticle

    var body: some View {
        BackgroundContainerView {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    AppSymbolTile(systemImage: article.topic.systemImage, tint: article.topic.tint)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(article.title)
                            .font(.largeTitle.bold())
                        Text(article.summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }

                    AppGlassCard(tint: article.topic.tint) {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(article.steps.enumerated()), id: \.offset) { index, step in
                                HelpStepRow(number: index + 1, text: step, tint: article.topic.tint)
                            }
                        }
                    }

                    if let tip = article.tip {
                        HelpCallout(title: "Tip", systemImage: "lightbulb.fill", text: tip, tint: .blue)
                    }

                    if let warning = article.warning {
                        HelpCallout(title: "Important", systemImage: "exclamationmark.triangle.fill", text: warning, tint: .orange)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(article.topic.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpStepRow: View {
    let number: Int
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(text)")
    }
}

private struct HelpCallout: View {
    let title: String
    let systemImage: String
    let text: String
    let tint: Color

    var body: some View {
        AppGlassCard(tint: tint) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    HelpGuideView()
}
