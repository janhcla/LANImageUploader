import Testing
import Foundation
@testable import LANImageUploader

struct ArchiveImagesBenchmarkTests {
    @Test func benchmarkArchiveImages() async throws {
        let fileService = FileService.shared

        // Setup mock images
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var images: [CapturedImage] = []
        for i in 0..<100 {
            let fileURL = tempDir.appendingPathComponent("image\(i).jpg")
            let data = Data(repeating: 0, count: 1024 * 1024) // 1MB
            try data.write(to: fileURL)
            images.append(CapturedImage(name: "image\(i)", fileURL: fileURL))
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        let result = try await fileService.archiveImages(images, for: Date())

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Archive 100 1MB images took: \(timeElapsed) seconds")

        #expect(result.saved == 100)

        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }
}
