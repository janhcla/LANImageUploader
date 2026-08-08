//
//  AppBackground.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 09/03/2025.
//

import SwiftUI

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animate = false

    var body: some View {
        ZStack {
            // Base Gradient
            if colorScheme == .dark {
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color(uiColor: .systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            
            // "Liquid" Refractive Blobs
            Circle()
                .fill(colorScheme == .dark ? Color.blue.opacity(0.13) : Color.blue.opacity(0.07))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animate ? 100 : -100, y: animate ? -150 : 150)
            
            Circle()
                .fill(colorScheme == .dark ? Color.purple.opacity(0.12) : Color.purple.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate ? -150 : 150, y: animate ? 100 : -100)
        }
        .ignoresSafeArea()
        .onAppear {
            updateAmbientMotion()
        }
        .onChange(of: reduceMotion) { _, _ in updateAmbientMotion() }
        .onChange(of: scenePhase) { _, _ in updateAmbientMotion() }
        .onDisappear { stopAmbientMotion() }
    }

    private func updateAmbientMotion() {
        guard !reduceMotion, scenePhase == .active else {
            stopAmbientMotion()
            return
        }
        guard !animate else { return }
        withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
            animate = true
        }
    }

    private func stopAmbientMotion() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animate = false
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

// MARK: - iOS 26 Liquid Glass

struct AppGlassCard<Content: View>: View {
    let tint: Color?
    @ViewBuilder let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                tint.map { .regular.tint($0.opacity(0.14)) } ?? .regular,
                in: .rect(cornerRadius: 24)
            )
    }
}

struct AppSymbolTile: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .shadow(color: tint.opacity(0.28), radius: 18, y: 10)
            .accessibilityHidden(true)
    }
}

struct GlassContainer<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder let content: Content
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1), .black.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct LiquidGlassModifier: ViewModifier {
    let depth: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                GlassContainer(cornerRadius: 16) {
                    Color.clear
                }
            )
            .offset(LiquidGlassUtils.calculateRefractionOffset(depth: depth, angle: 5))
    }
}

extension View {
    func liquidGlass(depth: CGFloat = 4) -> some View {
        self.modifier(LiquidGlassModifier(depth: depth))
    }
}
