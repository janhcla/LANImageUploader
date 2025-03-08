//
//  LaunchScreenView.swift
//  LANImageUploader
//
//  Created by Jan Hagen Clausen on 05/08/2025.
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App logo placeholder - you can replace this with your app logo
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("DermaSnap")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("(c) Jan H. Clausen, Midtbylægerne")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
            .padding(.top, 100)
            .padding(.bottom, 20)
        }
    }
}

// Preview
struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView()
    }
}

