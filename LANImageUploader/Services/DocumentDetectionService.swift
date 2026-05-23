import Foundation
import Vision
import UIKit

class DocumentDetectionService {
    static let shared = DocumentDetectionService()

    private init() {}

    func detectDocument(in image: UIImage) async -> DocumentQuad? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNDetectDocumentSegmentationRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNRectangleObservation],
                      let bestObservation = results.first else {
                    continuation.resume(returning: nil)
                    return
                }

                let quad = DocumentQuad(
                    topLeft: bestObservation.topLeft,
                    topRight: bestObservation.topRight,
                    bottomLeft: bestObservation.bottomLeft,
                    bottomRight: bestObservation.bottomRight
                )
                continuation.resume(returning: quad)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
