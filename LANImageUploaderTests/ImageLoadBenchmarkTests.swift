import Testing
import UIKit
import Foundation
@testable import LANImageUploader

struct ImageLoadBenchmarkTests {
    @Test @MainActor func benchmarkSyncImageLoad() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("largeImage.jpg")

        let rect = CGRect(x: 0, y: 0, width: 4000, height: 4000)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(UIColor.red.cgColor)
        context.fill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        let data = image.jpegData(compressionQuality: 1.0)!
        try data.write(to: fileURL)

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = UIImage(contentsOfFile: fileURL.path)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        print("Sync image load took: \(timeElapsed) seconds on MainThread")

        try FileManager.default.removeItem(at: fileURL)
    }
}
