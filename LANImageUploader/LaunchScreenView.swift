//
//  LaunchScreenView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 05/08/2025.
//

import SwiftUI

struct LaunchScreenView: View {
    @State private var isPulsing = false // State for pulsing animation
    @State private var textOpacity = 0.0 // State for text fade-in

    var body: some View {
        ZStack {
            Color.clear // Changed from Color(UIColor.systemBackground) to let AppBackground show
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Animated pulsing logo
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .scaleEffect(isPulsing ? 1.1 : 1.0) // Scales between 1.0 and 1.1
                    .animation(
                        Animation.easeInOut(duration: 0.8) // 0.8-second pulse
                            .repeatForever(autoreverses: true), // Loops continuously
                        value: isPulsing
                    )
                
                // Fading-in app name
                Text("ImageDropX")
                    .font(.title)
                    .fontWeight(.bold)
                    .opacity(textOpacity) // Controlled by state
                    .animation(.easeIn(duration: 0.5), value: textOpacity) // Fades in over 0.5 seconds
                
                Spacer()
                
                // Static copyright (or animate this too if desired)
                Text("(c) Jan H. Clausen, Midtbylægerne")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
            .padding(.top, 100)
            .padding(.bottom, 20)
        }
        .onAppear {
            // Trigger animations when the view appears
            isPulsing = true
            withAnimation {
                textOpacity = 1.0 // Fade in the text
            }
        }
    }
}

// Preview
struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
}
