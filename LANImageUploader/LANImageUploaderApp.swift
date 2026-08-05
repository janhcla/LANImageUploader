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
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingLaunchScreen = true

    init() {
        let fileService = FileService.shared
        let uploadService = ImageUploadService.shared
        let discoveryService = NetworkDiscovery.shared
        let hapticService = HapticFeedbackService.shared
        let launchArguments = ProcessInfo.processInfo.arguments

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
            passwordStore: passwordStore
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
            ZStack {
                // Launch Screen
                LaunchScreenView()
                    .opacity(isShowingLaunchScreen ? 1.0 : 0.0) // Fade out smoothly
                    .animation(.easeInOut(duration: 0.8), value: isShowingLaunchScreen) // Smooth animation
                    .zIndex(1) // Keep on top initially

                // Main Content
                Group {
                    if effectiveOnboardingCompleted {
                        HomeView()
                            .environmentObject(appData)
                            .opacity(isShowingLaunchScreen ? 0.0 : 1.0) // Fade in smoothly
                            .animation(.easeInOut(duration: 0.8), value: isShowingLaunchScreen)
                    } else {
                        OnboardingView()
                            .environmentObject(appData)
                            .opacity(isShowingLaunchScreen ? 0.0 : 1.0) // Fade in smoothly
                            .animation(.easeInOut(duration: 0.8), value: isShowingLaunchScreen)
                    }
                }
            }
            .background(AppBackground())
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isShowingLaunchScreen = false // Trigger the fade transition
                }

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
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    scheduleDailyImageSave()
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
        task.expirationHandler = {
        }
        Task {
            await appData.saveImagesToDatedFolder()
            task.setTaskCompleted(success: true)
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
