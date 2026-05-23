import SwiftUI

struct CroppingView: View {
    @Binding var documentQuad: DocumentQuad?
    let uiImage: UIImage
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appData: AppData

    @State private var quad: DocumentQuad
    @State private var imageRect: CGRect = .zero

    init(documentQuad: Binding<DocumentQuad?>, uiImage: UIImage) {
        self._documentQuad = documentQuad
        self.uiImage = uiImage
        self._quad = State(initialValue: documentQuad.wrappedValue ?? .defaultQuad)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let _ = updateImageRect(in: geometry.size)

                ZStack {
                    Color.black.ignoresSafeArea()

                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    // Draw Polygon
                    Path { path in
                        path.move(to: denormalize(point: quad.topLeft))
                        path.addLine(to: denormalize(point: quad.topRight))
                        path.addLine(to: denormalize(point: quad.bottomRight))
                        path.addLine(to: denormalize(point: quad.bottomLeft))
                        path.closeSubpath()
                    }
                    .stroke(Color.blue, lineWidth: 3)
                    .background(
                        Path { path in
                            path.move(to: denormalize(point: quad.topLeft))
                            path.addLine(to: denormalize(point: quad.topRight))
                            path.addLine(to: denormalize(point: quad.bottomRight))
                            path.addLine(to: denormalize(point: quad.bottomLeft))
                            path.closeSubpath()
                        }.fill(Color.blue.opacity(0.2))
                    )

                    // Draw Corners
                    CornerDragger(point: $quad.topLeft, imageRect: imageRect)
                    CornerDragger(point: $quad.topRight, imageRect: imageRect)
                    CornerDragger(point: $quad.bottomLeft, imageRect: imageRect)
                    CornerDragger(point: $quad.bottomRight, imageRect: imageRect)
                }
            }
            .navigationTitle("Adjust Crop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        documentQuad = quad
                        appData.hapticService.playNotification(type: .success)
                        dismiss()
                    }
                }
            }
        }
    }

    private func updateImageRect(in size: CGSize) {
        let imageSize = uiImage.size
        let viewRatio = size.width / size.height
        let imageRatio = imageSize.width / imageSize.height

        var rect = CGRect.zero
        if imageRatio > viewRatio {
            // Image is wider than view
            let height = size.width / imageRatio
            rect = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        } else {
            // Image is taller than view
            let width = size.height * imageRatio
            rect = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        }

        DispatchQueue.main.async {
            if imageRect != rect {
                imageRect = rect
            }
        }
    }

    private func denormalize(point: CGPoint) -> CGPoint {
        // Vision coordinates: (0,0) is bottom-left. We need to flip Y for SwiftUI where (0,0) is top-left.
        let x = imageRect.minX + point.x * imageRect.width
        let y = imageRect.minY + (1.0 - point.y) * imageRect.height
        return CGPoint(x: x, y: y)
    }
}

struct CornerDragger: View {
    @Binding var point: CGPoint
    let imageRect: CGRect

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 30, height: 30)
            .overlay(Circle().stroke(Color.blue, lineWidth: 3))
            .shadow(radius: 2)
            .position(denormalize(point: point))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let newPoint = normalize(point: value.location)
                        // Clamp between 0 and 1
                        let clampedX = max(0, min(1, newPoint.x))
                        let clampedY = max(0, min(1, newPoint.y))
                        point = CGPoint(x: clampedX, y: clampedY)
                    }
            )
    }

    private func denormalize(point: CGPoint) -> CGPoint {
        let x = imageRect.minX + point.x * imageRect.width
        let y = imageRect.minY + (1.0 - point.y) * imageRect.height
        return CGPoint(x: x, y: y)
    }

    private func normalize(point: CGPoint) -> CGPoint {
        let x = (point.x - imageRect.minX) / imageRect.width
        let y = 1.0 - ((point.y - imageRect.minY) / imageRect.height) // Flip Y back
        return CGPoint(x: x, y: y)
    }
}
