//
//  AppBackground.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 09/03/2025.
//

import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(
                gradient: Gradient(colors: [Color(uiColor: .systemGray2), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            LinearGradient(
                gradient: Gradient(colors: [Color(uiColor: .systemGray3), Color.white]),
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
        }
    }
}

// Add a container view that can be used across the app
struct BackgroundContainerView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppBackground()
            content
        }
        .background(Color.clear)
    }
}
