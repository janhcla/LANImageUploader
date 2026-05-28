import Testing
import Foundation
@testable import LANImageUploader

struct RestoreImagesBenchmarkTests {
    @Test func benchmarkRestoreImages() async throws {
        let fileService = FileService.shared

        // Setup mock images
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let datedFolderURL = docs.appendingPathComponent(dateString)
        try FileManager.default.createDirectory(at: datedFolderURL, withIntermediateDirectories: true)

        let imagesFolderURL = docs.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesFolderURL, withIntermediateDirectories: true)

        var imageURLs: [URL] = []
        for i in 0..<100 {
            let fileURL = datedFolderURL.appendingPathComponent("image\(i).jpg")
            let data = Data(repeating: 0, count: 1024 * 1024) // 1MB
            try data.write(to: fileURL)
            imageURLs.append(fileURL)
        }

        let existingImageURLs: Set<URL> = []
        var imagesToRestore: [(source: URL, destination: URL)] = []
        var seenDestinationURLs = existingImageURLs

        for imageURL in imageURLs {
            let destinationURL = imagesFolderURL.appendingPathComponent(imageURL.lastPathComponent)
            if seenDestinationURLs.insert(destinationURL).inserted {
                imagesToRestore.append((source: imageURL, destination: destinationURL))
            }
        }

        struct RestorationResult: Sendable {
            let successCount: Int
            let failureCount: Int
            let restoredImages: [CapturedImage]
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // The current implementation in ArchiveView
        let (restoredCount, failedCount, allRestored) = await withTaskGroup(of: RestorationResult.self) { group in
            for image in imagesToRestore {
                group.addTask {
                    do {
                        try? await fileService.removeItem(at: image.destination)
                        try await fileService.copyItem(at: image.source, to: image.destination)
                        let capturedImage = CapturedImage(
                            name: image.source.deletingPathExtension().lastPathComponent,
                            fileURL: image.destination)
                        return RestorationResult(successCount: 1, failureCount: 0, restoredImages: [capturedImage])
                    } catch {
                        print("Failed to restore archived image: \(error)")
                        return RestorationResult(successCount: 0, failureCount: 1, restoredImages: [])
                    }
                }
            }

            var success = 0
            var failure = 0
            var restored: [CapturedImage] = []
            for await res in group {
                success += res.successCount
                failure += res.failureCount
                restored.append(contentsOf: res.restoredImages)
            }
            return (success, failure, restored)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Restore 100 1MB images took: \(timeElapsed) seconds")

        #expect(restoredCount == 100)

        // Cleanup
        if FileManager.default.fileExists(atPath: datedFolderURL.path) {
            try FileManager.default.removeItem(at: datedFolderURL)
        }
        if FileManager.default.fileExists(atPath: imagesFolderURL.path) {
            try FileManager.default.removeItem(at: imagesFolderURL)
        }
    }
}
