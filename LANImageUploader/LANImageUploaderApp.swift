//
//  LANImageUploaderApp.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
import BackgroundTasks
import UIKit

// Add a custom UIHostingController to fix background issues
class ClearBackgroundHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set UIHostingController's view background to clear
        view.backgroundColor = .clear
    }
}

@main
struct LANImageUploaderApp: App {
    @AppStorage(Constants.UserDefaults.onboardingCompleted) var onboardingCompleted: Bool = false
    @StateObject private var appData: AppData
    @StateObject private var purchaseManager = StoreKitPurchaseManager()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init() {
        let fileService = FileService.shared
        let uploadService = ImageUploadService.shared
        let discoveryService = NetworkDiscovery.shared
        let hapticService = HapticFeedbackService.shared
        let launchArguments = ProcessInfo.processInfo.arguments

        #if DEBUG
        let isUITesting = launchArguments.contains { $0.hasPrefix("-uiTesting") }
        #endif

        #if DEBUG
        let passwordStore: ServerPasswordPersisting = launchArguments.contains("-uiTestingConfiguredServer")
            ? InMemoryServerPasswordStore()
            : KeychainServerPasswordStore()
        #else
        let passwordStore: ServerPasswordPersisting = KeychainServerPasswordStore()
        #endif

        let configuredAppData = AppData(
            fileService: fileService,
            uploadService: uploadService,
            discoveryService: discoveryService,
            hapticService: hapticService,
            passwordStore: passwordStore,
            persistsImageQueue: {
                #if DEBUG
                !isUITesting
                #else
                true
                #endif
            }()
        )

        #if DEBUG
        if launchArguments.contains("-uiTestingConfiguredServer") {
            configuredAppData.settings = ServerSettings(
                serverIP: "192.0.2.1",
                shareName: "TestShare",
                targetDirectory: "TestFolder",
                username: "test-user",
                port: nil
            )
            try? configuredAppData.savePassword("test-password")
        }
        if launchArguments.contains("-uiTestingEmptyLibrary") {
            configuredAppData.images = []
            configuredAppData.clearPendingUploadFiles()
        }
        if launchArguments.contains("-uiTestingPopulatedLibrary") {
            configuredAppData.images = UITestImageFixtures.makeCapturedImages()
            configuredAppData.clearPendingUploadFiles()
        }
        #endif

        _appData = StateObject(wrappedValue: configuredAppData)

        _ = NetworkMonitor.shared

        // Register the background task without 'weak' for struct (value type)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Constants.BackgroundTasks.dailyImageSave, using: nil) { [self] task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleAppRefreshTask(task: refreshTask)
        }
        // Set up UIKit appearance to ensure transparent backgrounds
        UITableView.appearance().backgroundColor = .clear
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().isTranslucent = true
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if effectiveOnboardingCompleted {
                    HomeView()
                        .environmentObject(appData)
                        .transition(.opacity)
                } else {
                    OnboardingView()
                        .environmentObject(appData)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: effectiveOnboardingCompleted)
            .onAppear {
                // Fix UIHostingController background after scene is created
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .forEach { window in
                            window.backgroundColor = .clear
                            window.rootViewController?.view.backgroundColor = .clear
                        }
                }
            }
            .task {
                await appData.premiumAccess.refreshPremiumOverrideEligibility()
                await purchaseManager.syncPurchasedEntitlements(accessController: appData.premiumAccess)
                purchaseManager.startObservingTransactionUpdates(accessController: appData.premiumAccess)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    scheduleDailyImageSave()
                    Task {
                        await purchaseManager.syncPurchasedEntitlements(accessController: appData.premiumAccess)
                    }
                }
            }
        }
    }

    private var effectiveOnboardingCompleted: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestingOnboarding") { return false }
        if arguments.contains("-uiTestingHome") { return true }
        return onboardingCompleted
    }

    private func handleAppRefreshTask(task: BGAppRefreshTask) {
        scheduleDailyImageSave()
        let archiveTask = Task {
            let outcome = await appData.saveImagesToDatedFolder()
            guard !Task.isCancelled else { return }
            switch outcome {
            case .saved, .noImages:
                task.setTaskCompleted(success: true)
            case .failed:
                task.setTaskCompleted(success: false)
            }
        }
        task.expirationHandler = {
            archiveTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    private func scheduleDailyImageSave() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.BackgroundTasks.dailyImageSave)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 0
        components.second = 0
        if let midnight = calendar.date(from: components),
           let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight) {
            request.earliestBeginDate = nextMidnight
        }
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            if let bgError = error as? BGTaskScheduler.Error, bgError.code == .unavailable {
                _ = bgError
            } else {
                _ = error
            }
        }
    }
}

#if DEBUG
private enum UITestImageFixtures {
    private struct Fixture {
        let name: String
        let color: UIColor
        let systemImage: String
    }

    static func makeCapturedImages() -> [CapturedImage] {
        let fixtures = [
            Fixture(name: "Sample Document", color: .systemBlue, systemImage: "doc.text.fill"),
            Fixture(name: "Sample Photo", color: .systemGreen, systemImage: "photo.fill"),
            Fixture(name: "Sample Receipt", color: .systemOrange, systemImage: "receipt.fill")
        ]
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LensBridgeUITestFixtures-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return []
        }

        return fixtures.enumerated().compactMap { index, fixture in
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 1200))
            let image = renderer.image { context in
                fixture.color.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 900, height: 1200))

                let configuration = UIImage.SymbolConfiguration(pointSize: 180, weight: .semibold)
                let symbol = UIImage(systemName: fixture.systemImage, withConfiguration: configuration)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal)
                symbol?.draw(in: CGRect(x: 330, y: 330, width: 240, height: 240))

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                (fixture.name as NSString).draw(
                    in: CGRect(x: 90, y: 650, width: 720, height: 100),
                    withAttributes: [
                        .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                        .foregroundColor: UIColor.white,
                        .paragraphStyle: paragraph
                    ]
                )
            }

            guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
            let fileURL = directory.appendingPathComponent("sample-\(index + 1).jpg")
            do {
                try data.write(to: fileURL, options: .atomic)
                return CapturedImage(
                    name: fixture.name,
                    fileURL: fileURL,
                    isDocumentScan: index != 1
                )
            } catch {
                return nil
            }
        }
    }
}
#endif
