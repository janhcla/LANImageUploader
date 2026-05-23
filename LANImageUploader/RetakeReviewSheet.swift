//
//  RetakeReviewSheet.swift
//  LANImageUploader
//

import SwiftUI

struct RetakeReviewSheet: View {
    let newImage: UIImage
    let onUseNew: () -> Void
    let onDiscard: () -> Void
    let onRetakeAgain: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Text("Review Retake")
                    .font(.title2.weight(.bold))
                    .padding(.top)

                Image(uiImage: newImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 400)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 5)

                VStack(spacing: 16) {
                    Button(action: onUseNew) {
                        Label("Use New Image", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BlueButtonStyle())

                    Button(action: onRetakeAgain) {
                        Label("Retake Again", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OrangeButtonStyle())

                    Button(action: onDiscard) {
                        Label("Discard & Keep Old", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(GrayButtonStyle())
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }
}
