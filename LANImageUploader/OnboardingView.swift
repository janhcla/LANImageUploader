//
//  OnboardingView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 22/02/2025.
//

import SwiftUI
import AMSMB2
import Network

public struct OnboardingView: View {
    @EnvironmentObject var appData: AppData
    @AppStorage("onboardingCompleted") var onboardingCompleted: Bool = false
    @State private var currentStep = 0
    @State private var showHelpGuide = false
    @State private var showNetworkSetup = false

    private let steps: [OnboardingStep] = [
        .welcome, .features, .settings, .tutorial, .helpGuide, .completion
    ]

    public var body: some View {
        BackgroundContainerView {
            NavigationStack {
                VStack {
                    switch steps[currentStep] {
                    case .welcome:
                        WelcomePage(nextAction: nextStep)
                    case .features:
                        FeaturesPage(nextAction: nextStep)
                    case .settings:
                        if showNetworkSetup {
                            NetworkSetupView(nextAction: nextStep)
                                .environmentObject(appData)
                        } else {
                            OnboardingSettingsView(nextAction: nextStep)
                                .environmentObject(appData)
                        }
                    case .tutorial:
                        TutorialPage(nextAction: nextStep)
                    case .helpGuide:
                        HelpGuideIntroPage(nextAction: nextStep, showHelpGuide: $showHelpGuide)
                    case .completion:
                        CompletionPage(completeAction: completeOnboarding)
                    }
                }
                .navigationBarHidden(true)
                .background(Color.clear)
                .scrollContentBackground(.hidden)
                .sheet(isPresented: $showHelpGuide) {
                    HelpGuideView()
                }
                .onChange(of: currentStep) { _, newStep in
                    if steps[newStep] == .settings {
                        checkSettings()
                    }
                }
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

    private func checkSettings() {
        let settings = appData.settings
        let password = appData.getPassword()
        showNetworkSetup = settings.serverIP.isEmpty || settings.shareName.isEmpty ||
                           (settings.targetDirectory?.isEmpty ?? true) || settings.username.isEmpty ||
                           password == nil
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
    @State private var port = ""

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
                TextField("", text: $port)
                    .keyboardType(.numberPad)
                    .placeholder(when: port.isEmpty) {
                        Text("Port (optional)")
                            .foregroundStyle(.gray)
                    }
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
            Text("Uploads won't work without server details. Please set them up in Settings later if you skip now.")
        }
    }

    func saveSettings() {
            // Validate port if provided
            let portNumber: Int?
            if !port.isEmpty {
                guard let number = Int(port), number > 0, number <= 65535 else {
                    return
                }
                portNumber = number
            } else {
                portNumber = nil
            }
            
            appData.settings = ServerSettings(
                serverIP: serverIP,
                shareName: shareName,
                targetDirectory: targetDirectory,
                username: username,
                port: portNumber  // Add port to settings
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
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
//                )
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
            Text("You're Ready!")
                .font(.title)
                .fontWeight(.bold)
            Text("Start documenting skin conditions now. Set up server details in Settings if you haven't already.")
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

struct NetworkSetupView: View {
    @EnvironmentObject var appData: AppData
    let nextAction: () -> Void
    @State private var targetDirectory = ""
    @State private var username = ""
    @State private var password = ""
    @State private var port = ""  // Add this line
    @State private var showWarning = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var networkInfo: NetworkInfo?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Network Setup")
                .font(.title)
                .fontWeight(.bold)
            Text("Enter the target folder and credentials to auto-fill server details (recommended). You can skip and set up later.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
                .padding(.horizontal)
            Form {
                TextField("Target Directory (e.g., MediaCapture)", text: $targetDirectory)
                    .autocapitalization(.none)
                TextField("Username (e.g., WORKGROUP\\user)", text: $username)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                TextField("Port (optional)", text: $port)
                    .keyboardType(.numberPad)
            }
            .frame(maxHeight: 200)
            Button("Auto-Fill and Save") {
                Task { await autoFillNetworkInfo() }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canAutoFill ? Color.blue : Color.gray)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .disabled(!canAutoFill)
            Button("Skip") {
                showWarning = true
            }
            .foregroundStyle(.gray)
            Spacer()
        }
        .alert("Settings Incomplete", isPresented: $showWarning) {
            Button("Set Up Now", role: .cancel) {}
            Button("Skip Anyway") { nextAction() }
        } message: {
            Text("Uploads won't work without server details. Set them up in Settings later if you skip now.")
        }
        .alert("Network Error", isPresented: $showError) {
            Button("Try Again", role: .cancel) {}
            Button("Skip") { nextAction() }
        } message: {
            Text(errorMessage)
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("Save") { saveSettings() }
            Button("Discard") { nextAction() }
        } message: {
            Text("Server details retrieved successfully:\nIP: \(networkInfo?.serverIP ?? "")\nShare: \(networkInfo?.shareName ?? "")\nPath: \(networkInfo?.targetDirectory ?? "")")
        }
    }

    var canAutoFill: Bool {
        !targetDirectory.isEmpty && !username.isEmpty && !password.isEmpty
    }

    func saveSettings() {
        guard let info = networkInfo else { return }

        // Validate port if provided
        let portNumber: Int?
        if !port.isEmpty {
            guard let number = Int(port), number > 0, number <= 65535 else {
                showError = true
                errorMessage = "Please enter a valid port number (1-65535)"
                return
            }
            portNumber = number
        } else {
            portNumber = nil
        }
        
        appData.settings = ServerSettings(
            serverIP: info.serverIP,  // Use info.serverIP instead of serverIP
            shareName: info.shareName,  // Use info.shareName instead of shareName
            targetDirectory: info.targetDirectory,
            username: username,
            port: portNumber
        )
        try? appData.savePassword(password)
        nextAction()
    }

    private func autoFillNetworkInfo() async {
            do {
                let portNumber = Int(port)
                let info = try await retrieveNetworkInfo(
                    targetFolder: targetDirectory,
                    username: username,
                    password: password,
                    directIP: nil,
                    port: portNumber
                )
                await MainActor.run {
                    networkInfo = info
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    showError = true
                    errorMessage = "Failed to retrieve network info: \(error.localizedDescription)"
                }
            }
        }
}

#Preview {
    OnboardingView()
        .environmentObject(AppData())
}
