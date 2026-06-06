//
//  ButtonStyles.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 02/03/2025.
//

import SwiftUI

struct LiquidButtonStyle: ButtonStyle {
    var backgroundColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Glass effect base
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(backgroundColor.opacity(0.3))
                        .background(.ultraThinMaterial)
                    
                    // Inner highlight
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .padding(1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
            .shadow(color: backgroundColor.opacity(0.2), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 5)
    }
}

struct GrayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LiquidButtonStyle(backgroundColor: .gray).makeBody(configuration: configuration)
    }
}

struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LiquidButtonStyle(backgroundColor: .orange).makeBody(configuration: configuration)
    }
}

struct BlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        LiquidButtonStyle(backgroundColor: .blue).makeBody(configuration: configuration)
    }
}

struct FullWidthGlassButtonLabel: View {
    let title: String
    let systemImage: String?

    init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
    }
}
