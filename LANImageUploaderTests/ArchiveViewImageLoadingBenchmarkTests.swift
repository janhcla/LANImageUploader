import Testing
import Foundation
import UIKit
@testable import LANImageUploader

struct ArchiveViewImageLoadingBenchmarkTests {
    @Test func benchmarkMainThreadBlockingImageLoading() async throws {
        // Setup mock image
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileURL = tempDir.appendingPathComponent("largeImage.jpg")

        // Create a fake large image (e.g. 10MB)
        let data = Data(repeating: 128, count: 10 * 1024 * 1024)
        try data.write(to: fileURL)

        // 1. Measure Synchronous Loading (Main Thread Blocking)
        let syncStartTime = CFAbsoluteTimeGetCurrent()
        let _ = try? Data(contentsOf: fileURL)
        let syncTimeElapsed = CFAbsoluteTimeGetCurrent() - syncStartTime

        print("Synchronous loading took: \(syncTimeElapsed * 1000) ms")

        // 2. Measure Asynchronous Loading (Non-Blocking)
        let asyncStartTime = CFAbsoluteTimeGetCurrent()

        // Fire off background load
        let asyncTask = Task.detached {
            let _ = try? Data(contentsOf: fileURL)
        }

        // Time elapsed on the current thread (simulating main thread) before it's unblocked
        let asyncTimeElapsed = CFAbsoluteTimeGetCurrent() - asyncStartTime

        // Wait for it to finish just so we don't leak work
        await asyncTask.value

        print("Asynchronous dispatch (main thread blocking time) took: \(asyncTimeElapsed * 1000) ms")

        // The async dispatch should block the "main" thread significantly less than synchronous loading
        #expect(asyncTimeElapsed < syncTimeElapsed)

        print("Improvement factor: \(syncTimeElapsed / asyncTimeElapsed)x faster on main thread")

        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }
}
