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
    @State private var isApplying = false

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
                    Button {
                        guard !isApplying else { return }
                        isApplying = true
                        onUseNew()
                    } label: {
                        HStack(spacing: 8) {
                            if isApplying {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isApplying ? "Replacing…" : "Use New Image")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BlueButtonStyle())
                    .disabled(isApplying)

                    Button(action: onRetakeAgain) {
                        Label("Retake Again", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(OrangeButtonStyle())
                    .disabled(isApplying)

                    Button(action: onDiscard) {
                        Label("Discard & Keep Old", systemImage: "xmark.circle")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(GrayButtonStyle())
                    .disabled(isApplying)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .interactiveDismissDisabled(isApplying)
    }
}
