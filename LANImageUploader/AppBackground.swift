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
                gradient: Gradient(colors: [Color(.systemGray2), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        } else {
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemGray6), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}
