//
//  OnboardingView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 22/02/2025.
//

import SwiftUI

public struct OnboardingView: View {
    @EnvironmentObject var appData: AppData
    @AppStorage("onboardingCompleted") var onboardingCompleted: Bool = false
    @State private var currentStep = 0
    @State private var showHelpGuide = false

    private let steps: [OnboardingStep] = [
        .welcome, .features, .settings, .tutorial, .helpGuide, .completion
    ]

    public var body: some View {
        NavigationStack {
            VStack {
                switch steps[currentStep] {
                case .welcome:
                    WelcomePage(nextAction: nextStep)
                case .features:
                    FeaturesPage(nextAction: nextStep)
                case .settings:
                    OnboardingSettingsView(nextAction: nextStep)
                        .environmentObject(appData)
                case .tutorial:
                    TutorialPage(nextAction: nextStep)
                case .helpGuide:
                    HelpGuideIntroPage(nextAction: nextStep, showHelpGuide: $showHelpGuide)
                case .completion:
                    CompletionPage(completeAction: completeOnboarding)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showHelpGuide) {
                HelpGuideView()
            }
        }
    }

    func nextStep() {
        if currentStep < steps.count - 1 {
            currentStep += 1
        }
    }

    func completeOnboarding() {
        onboardingCompleted = true
    }
}

public enum OnboardingStep {
    case welcome, features, settings, tutorial, helpGuide, completion
}

struct WelcomePage: View {
    let nextAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Welcome to DermaSnap!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your professional tool for documenting skin diseases and seeking teledermatologic guidance.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("Copyright © 2025 Jan H. Clausen, Midtbylægerne")
                .font(.footnote)
                .foregroundStyle(.gray)
            Spacer()
            Button("Get Started") {
                nextAction()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct FeaturesPage: View {
    let nextAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Key Features")
                .font(.title)
                .fontWeight(.bold)
            VStack(alignment: .center, spacing: 20) {
                FeatureItem(icon: "camera.fill", title: "Capture Images", description: "Take high-quality photos of skin conditions.")
                FeatureItem(icon: "photo.on.rectangle", title: "Manage Gallery", description: "View and organize your captured images.")
                FeatureItem(icon: "arrow.up.circle", title: "Upload Securely", description: "Send images to a local server for consultation.")
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: 500)
            Spacer()
            Button("Next") {
                nextAction()
            }
            .frame(maxWidth: 300)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct OnboardingSettingsView: View {
    @EnvironmentObject var appData: AppData
    let nextAction: () -> Void
    @State private var serverIP = ""
    @State private var shareName = ""
    @State private var targetDirectory = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showWarning = false

    var areSettingsComplete: Bool {
        !serverIP.isEmpty && !shareName.isEmpty && !targetDirectory.isEmpty && !username.isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Set Up Your Server")
                .font(.title)
                .fontWeight(.bold)
            Text("Enter your server details to enable image uploads (recommended). You can skip this and set it up later in Settings.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
                .padding(.horizontal)
            Form {
                TextField("Server IP (e.g., 192.168.1.100)", text: $serverIP)
                    .textContentType(.URL)
                    .keyboardType(.numbersAndPunctuation)
                    .autocapitalization(.none)
                TextField("Share Name (e.g., PatientImages)", text: $shareName)
                    .autocapitalization(.none)
                TextField("Target Directory (e.g., Uploads)", text: $targetDirectory)
                    .autocapitalization(.none)
                TextField("Username", text: $username)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .frame(maxHeight: 200)
            Button("Save and Next") {
                saveSettings()
                nextAction()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            Button("Skip") {
                if !areSettingsComplete {
                    showWarning = true
                } else {
                    nextAction()
                }
            }
            .foregroundStyle(.gray)
            Spacer()
        }
        .alert("Settings Incomplete", isPresented: $showWarning) {
            Button("Set Up Now", role: .cancel) {}
            Button("Skip Anyway") { nextAction() }
        } message: {
            Text("Uploads won’t work without server details. Please set them up in Settings later if you skip now.")
        }
    }

    func saveSettings() {
        appData.settings = ServerSettings(
            serverIP: serverIP,
            shareName: shareName,
            targetDirectory: targetDirectory,
            username: username
        )
        try? appData.savePassword(password)
    }
}

struct TutorialPage: View {
    let nextAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("How to Use DermaSnap")
                .font(.title)
                .fontWeight(.bold)
            VStack(spacing: 20) {
                StepItem(number: 1, text: "Tap 'Take Photo' to capture an image.", imageName: "capture_screen")
                StepItem(number: 2, text: "View and rename images in the gallery.", imageName: "gallery_screen")
                StepItem(number: 3, text: "Upload images to your server (settings required).", imageName: "upload_screen")
            }
            .padding(.horizontal, 10)
            Spacer()
            Button("Next") {
                nextAction()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct StepItem: View {
    let number: Int
    let text: String
    let imageName: String

    var body: some View {
        HStack(spacing: 15) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .onAppear {
                    print("Loading image: \(imageName) – Found: \(UIImage(named: imageName) != nil)")
                }
                .overlay(
                    Text("Image not found: \(imageName)")
                        .foregroundStyle(.red)
                        .opacity(UIImage(named: imageName) == nil ? 1 : 0)
                )
            VStack(alignment: .leading, spacing: 10) {
                Text("\(number). \(text)")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct HelpGuideIntroPage: View {
    let nextAction: () -> Void
    @Binding var showHelpGuide: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Need Help?")
                .font(.title)
                .fontWeight(.bold)
            Text("Access the Help Guide anytime for detailed instructions on setting up your server and using the app.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("View Help Guide") {
                showHelpGuide = true
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            Spacer()
            Button("Next") {
                nextAction()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

struct CompletionPage: View {
    let completeAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("You’re Ready!")
                .font(.title)
                .fontWeight(.bold)
            Text("Start documenting skin conditions now. Set up server details in Settings if you haven’t already.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .foregroundStyle(.green)
            Spacer()
            Button("Start Using DermaSnap") {
                completeAction()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

//import SwiftUI
//
//public struct OnboardingView: View { // Changed to 'public' for access from other files
//    @EnvironmentObject var appData: AppData
//    @AppStorage("onboardingCompleted") var onboardingCompleted: Bool = false
//    @State private var currentStep = 0
//    @State private var showHelpGuide = false
//
//    private let steps: [OnboardingStep] = [
//        .welcome,
//        .features,
//        .settings,
//        .tutorial,
//        .helpGuide,
//        .completion
//    ]
//
//    public var body: some View { // Changed to 'public' for consistency
//        NavigationStack {
//            VStack {
//                switch steps[currentStep] {
//                case .welcome:
//                    WelcomePage(nextAction: nextStep)
//                case .features:
//                    FeaturesPage(nextAction: nextStep)
//                case .settings:
//                    OnboardingSettingsView(nextAction: nextStep)
//                        .environmentObject(appData)
//                case .tutorial:
//                    TutorialPage(nextAction: nextStep)
//                case .helpGuide:
//                    HelpGuideIntroPage(nextAction: nextStep, showHelpGuide: $showHelpGuide)
//                case .completion:
//                    CompletionPage(completeAction: completeOnboarding)
//                }
//            }
//            .navigationBarHidden(true)
//            .sheet(isPresented: $showHelpGuide) {
//                HelpGuideView()
//            }
//        }
//    }
//
//    func nextStep() {
//        if currentStep < steps.count - 1 {
//            currentStep += 1
//        }
//    }
//
//    func completeOnboarding() {
//        onboardingCompleted = true
//    }
//}
//
//public enum OnboardingStep { // Changed to 'public' for access
//    case welcome, features, settings, tutorial, helpGuide, completion
//}
//
//struct WelcomePage: View {
//    let nextAction: () -> Void
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Spacer()
//            Text("Welcome to DermaSnap!")
//                .font(.largeTitle)
//                .fontWeight(.bold)
//            Text("Your professional tool for documenting skin diseases and seeking teledermatologic guidance.")
//                .font(.body)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            Text("Copyright © 2025 Jan H. Clausen, Midtbylægerne")
//                .font(.footnote)
//                .foregroundStyle(.gray)
//            Spacer()
//            Button("Get Started") {
//                nextAction()
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(Color.blue)
//            .foregroundStyle(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 10))
//            .padding(.horizontal)
//        }
//        .padding(.vertical)
//    }
//}
//
//struct FeaturesPage: View {
//    let nextAction: () -> Void
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Spacer()
//            Text("Key Features")
//                .font(.title)
//                .fontWeight(.bold)
//            VStack(alignment: .center, spacing: 20) { // Centered alignment, increased spacing
//                FeatureItem(icon: "camera.fill", title: "Capture Images", description: "Take high-quality photos of skin conditions.")
//                FeatureItem(icon: "photo.on.rectangle", title: "Manage Gallery", description: "View and organize your captured images.")
//                FeatureItem(icon: "arrow.up.circle", title: "Upload Securely", description: "Send images to a local server for consultation.")
//            }
//            .padding(.horizontal, 30) // Add horizontal padding for balance
//            .frame(maxWidth: 500) // Limit width for readability on wide screens
//            Spacer()
//            Button("Next") {
//                nextAction()
//            }
//            .frame(maxWidth: 300) // Reduced width for centered, balanced look
//            .padding()
//            .background(Color.blue)
//            .foregroundStyle(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 10))
//            .padding(.horizontal)
//        }
//        .padding(.vertical, 40) // Increased vertical padding for breathing room
//    }
//}
//
//struct FeatureItem: View {
//    let icon: String
//    let title: String
//    let description: String
//
//    var body: some View {
//        HStack(spacing: 20) { // Increased spacing for better readability
//            Image(systemName: icon)
//                .font(.title2) // 24pt, consistent with HIG
//                .foregroundStyle(.blue)
//            VStack(alignment: .leading, spacing: 5) {
//                Text(title)
//                    .font(.headline)
//                Text(description)
//                    .font(.subheadline)
//                    .foregroundStyle(.gray)
//                    .lineLimit(2) // Ensure descriptions don’t overflow
//            }
//            Spacer() // Push content to the left, avoiding full-width stretch
//        }
//        .padding(.vertical, 10) // Add vertical padding for each item
//    }
//}
//
//struct OnboardingSettingsView: View {
//    @EnvironmentObject var appData: AppData
//    let nextAction: () -> Void
//    @State private var serverURL = ""
//    @State private var destinationDirectory = ""
//    @State private var username = ""
//    @State private var password = ""
//    @State private var showWarning = false
//
//    var areSettingsComplete: Bool {
//        !serverURL.isEmpty && !destinationDirectory.isEmpty && !username.isEmpty && !password.isEmpty
//    }
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Spacer()
//            Text("Set Up Your Server")
//                .font(.title)
//                .fontWeight(.bold)
//            Text("Enter your server details to enable image uploads (recommended). You can skip this and set it up later in Settings.")
//                .font(.subheadline)
//                .multilineTextAlignment(.center)
//                .foregroundStyle(.gray)
//                .padding(.horizontal)
//            Form {
//                TextField("Server IP (e.g., 192.168.1.100)", text: $serverURL)
//                    .textContentType(.URL)
//                    .keyboardType(.URL)
//                    .autocapitalization(.none)
//                TextField("Destination Directory (e.g., /uploads)", text: $destinationDirectory)
//                TextField("Username", text: $username)
//                    .textContentType(.username)
//                SecureField("Password", text: $password)
//                    .textContentType(.password)
//            }
//            .frame(maxHeight: 200)
//            Button("Save and Next") {
//                saveSettings()
//                nextAction()
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(Color.blue)
//            .foregroundStyle(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 10))
//            .padding(.horizontal)
//            Button("Skip") {
//                if !areSettingsComplete {
//                    showWarning = true
//                } else {
//                    nextAction()
//                }
//            }
//            .foregroundStyle(.gray)
//            Spacer()
//        }
//        .alert("Settings Incomplete", isPresented: $showWarning) {
//            Button("Set Up Now", role: .cancel) {}
//            Button("Skip Anyway") { nextAction() }
//        } message: {
//            Text("Uploads won’t work without server details. Please set them up in Settings later if you skip now.")
//        }
//    }
//
//    func saveSettings() {
//        var finalURL = serverURL
//        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
//            finalURL = "http://\(finalURL)"
//        }
//        appData.settings = ServerSettings(serverURL: finalURL, destinationDirectory: destinationDirectory, username: username)
//        try? appData.savePassword(password)
//    }
//}
//
//struct TutorialPage: View {
//    let nextAction: () -> Void
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Spacer()
//            Text("How to Use DermaSnap")
//                .font(.title)
//                .fontWeight(.bold)
//            VStack(spacing: 20) {
//                StepItem(number: 1, text: "Tap 'Take Photo' to capture an image.", imageName: "capture_screen")
//                StepItem(number: 2, text: "View and rename images in the gallery.", imageName: "gallery_screen")
//                StepItem(number: 3, text: "Upload images to your server (settings required).", imageName: "upload_screen")
//            }
//            .padding(.horizontal, 10)
//            Spacer()
//            Button("Next") {
//                nextAction()
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(Color.blue)
//            .foregroundStyle(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 10))
//            .padding(.horizontal)
//        }
//        .padding(.vertical)
//    }
//}
//
//struct StepItem: View {
//    let number: Int
//    let text: String
//    let imageName: String
//
//    var body: some View {
//        HStack(spacing: 15) {
//            Image(imageName)
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(maxWidth: .infinity, maxHeight: 150)
//                .clipShape(RoundedRectangle(cornerRadius: 12)) // Softer rounded corners
//                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2) // Subtle drop shadow
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(Color.gray.opacity(0.2), lineWidth: 1) // Optional subtle border
//                )
//                .onAppear {
//                    print("Loading image: \(imageName) – Found: \(UIImage(named: imageName) != nil)")
//                }
//                .overlay(
//                    Text("Image not found: \(imageName)")
//                        .foregroundStyle(.red)
//                        .opacity(UIImage(named: imageName) == nil ? 1 : 0)
//                )
//            VStack(alignment: .leading, spacing: 10) {
//                Text("\(number). \(text)")
//                    .font(.body)
//                    .frame(maxWidth: .infinity, alignment: .leading)
//            }
//        }
//    }
//}
//
//
//struct HelpGuideIntroPage: View {
//    let nextAction: () -> Void
//    @Binding var showHelpGuide: Bool
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Spacer()
//            Text("Need Help?")
//                .font(.title)
//                .fontWeight(.bold)
//            Text("Access the Help Guide anytime for detailed instructions on setting up your server and using the app.")
//                .font(.body)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            Button("View Help Guide") {
//                showHelpGuide = true
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(Color.gray)
//            .foregroundStyle(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 10))
//            .padding(.horizontal)
//            Spacer()
//            Button("Next") {
//                nextAction()
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(Color.blue)
//            .foregroundStyle(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 10))
//            .padding(.horizontal)
//        }
//        .padding(.vertical)
//    }
//}
//
//struct CompletionPage: View {
//    let completeAction: () -> Void
//
//    var body: some View {
//        VStack(spacing: 20) {
//            Spacer()
//            Text("You’re Ready!")
//                .font(.title)
//                .fontWeight(.bold)
//            Text("Start documenting skin conditions now. Set up server details in Settings if you haven’t already.")
//                .font(.body)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            Image(systemName: "checkmark.circle.fill")
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                .frame(width: 100, height: 100)
//                .foregroundStyle(.green)
//            Spacer()
//            Button("Start Using DermaSnap") {
//                completeAction()
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//            .background(Color.blue)
//            .foregroundStyle(.white)
//            .clipShape(RoundedRectangle(cornerRadius: 10))
//            .padding(.horizontal)
//        }
//        .padding(.vertical)
//    }
//}
