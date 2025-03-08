//
//  LANImageUploaderApp.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import SwiftUI
import BackgroundTasks

@main
struct LANImageUploaderApp: App {
    @AppStorage("onboardingCompleted") var onboardingCompleted: Bool = false
    @StateObject private var appData = AppData()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingLaunchScreen = true

    init() {
        // Register the background task without 'weak' for struct (value type)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.janhagenclausen.LANImageUploader.dailyImageSave", using: nil) { [self] task in
            handleAppRefreshTask(task: task as! BGAppRefreshTask)
        }
        print("Onboarding completed state at launch: \(onboardingCompleted)")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isShowingLaunchScreen {
                    LaunchScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                }
                if onboardingCompleted {
                    HomeView()
                        .environmentObject(appData)
                } else {
                    OnboardingView()
                        .environmentObject(appData)
                }
            }
            .onAppear {
                // Simulate a delay for the launch screen
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation {
                        isShowingLaunchScreen = false
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("Scene phase changed from \(oldPhase) to \(newPhase)")
                if newPhase == .active {
                    scheduleDailyImageSave()
                }
            }
        }
    }

    private func handleAppRefreshTask(task: BGAppRefreshTask) {
        scheduleDailyImageSave()
        task.expirationHandler = {
            print("Task expired before completion")
        }
        appData.saveImagesToDatedFolder()
        task.setTaskCompleted(success: true)
    }

    private func scheduleDailyImageSave() {
        let request = BGAppRefreshTaskRequest(identifier: "com.janhagenclausen.LANImageUploader.dailyImageSave")
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 0
        components.minute = 0
        components.second = 0
        if let midnight = calendar.date(from: components) {
            let nextMidnight = calendar.date(byAdding: .day, value: 1, to: midnight)!
            request.earliestBeginDate = nextMidnight
        }
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled daily image save for \(request.earliestBeginDate?.description ?? "unknown")")
        } catch {
            print("Failed to schedule daily image save: \(error)")
        }
    }
}
